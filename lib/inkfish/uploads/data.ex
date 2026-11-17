defmodule Inkfish.Uploads.Data do
  @moduledoc """
  Reads an upload's unpacked submission tree.

  Two shapes of the tree exist:

    * `read_data/1` builds the full tree the code viewer renders, with
      the contents of every displayable text file attached. It walks the
      whole tree per call, so it is a display-time function only.
    * `file_index/1` returns the much smaller `%{paths, line_counts}` map
      used to anchor line comments, cached on disk next to the upload.
      Comment validation must use the index rather than `read_data/1`:
      validation runs once per grading-script POST, and re-walking a
      many-hundred-file repo per request both dominated request time and,
      with a symlink cycle in the tree, did not terminate at all (#154).

  Both walks use `File.lstat` and never follow symlinks: the sanitizer
  deliberately keeps in-tree relative links, so a followed link could
  re-walk a subtree forever or recurse without bound.
  """

  import Inkfish.Text, only: [corrupt_invalid_utf8: 1]
  alias Inkfish.Uploads.Upload

  # The size cap from `set_mode/3`: only files at or under it ever got
  # `:text` attached by `read_data/1`, so only they ever had a line count
  # to validate against. Keeping the same cap preserves that validation
  # behavior exactly.
  @text_limit 32_768

  @index_name "files_index.json"

  def read_data(%Upload{} = upload) do
    read_tree(Upload.unpacked_path(upload))
  end

  def read_tree(base) do
    read_tree(base, "")
  end

  def read_tree(base, rel) do
    path = Path.join(base, rel)

    # `lstat`, not `stat`: the tree may contain in-tree relative symlinks
    # (the sanitizer keeps those), and following them here can re-walk a
    # subtree without bound or recurse forever on a cycle. A symlink is
    # reported as a leaf with its link type instead.
    case File.lstat(path) do
      {:ok, stat} ->
        info = %{
          key: rel,
          path: rel,
          label: label(rel),
          type: to_string(stat.type),
          size: stat.size
        }

        read_item(base, rel, info)

      other ->
        msg = inspect(other)

        %{
          key: rel,
          path: rel,
          label: label(rel),
          type: "text/plain",
          size: String.length(msg),
          text: msg
        }
    end
  end

  def label(path) do
    if path == "" do
      "[root]"
    else
      Path.basename(path)
    end
  end

  def read_list(base, rel, items) do
    Enum.map(items, fn item ->
      relp = Path.join(rel, item)
      read_tree(base, relp)
    end)
  end

  def omega_text do
    """
    Bonus file for extra grading space.
    - one
    - two
    - green
    - lemon
    """
  end

  def omega_name, do: "Ω_grading_extra.txt"

  def omega_line_count do
    omega_text() |> String.split("\n") |> length()
  end

  def add_xtra_file(nodes, rel) do
    if rel == "" do
      name = omega_name()
      text = omega_text()

      xtra = %{
        key: name,
        path: name,
        label: name,
        type: "text/plain",
        size: String.length(text),
        text: text
      }

      [xtra | nodes]
    else
      nodes
    end
  end

  def read_item(base, rel, %{type: "directory"} = info) do
    path = Path.join(base, rel)
    items = File.ls!(path)

    nodes =
      read_list(base, rel, items)
      |> add_xtra_file(rel)
      |> Enum.sort_by(& &1.path)

    Map.put(info, :nodes, nodes)
  end

  def read_item(base, rel, %{type: "regular"} = info) do
    info
    |> set_mode(base, rel)
    |> read_text(base, rel)
  end

  def read_item(_base, _rel, info) do
    info
  end

  def set_mode(info, base, rel) do
    name = Path.basename(rel)

    cond do
      info.size > 32768 ->
        info

      name =~ ~r/^\./ ->
        info

      name =~ ~r/\.ex$/i ->
        Map.put(info, :mode, "elixir")

      name =~ ~r/\.c$/i ->
        Map.put(info, :mode, "clike")

      text_file?(Path.join(base, rel)) ->
        Map.put(info, :mode, "null")

      true ->
        info
    end
  end

  def read_text(info, base, rel) do
    path = Path.join(base, rel)

    if info[:mode] && text_file?(path) do
      text = File.read!(path)
      Map.put(info, :text, corrupt_invalid_utf8(text))
    else
      info
    end
  end

  def text_file?(path) do
    {type, 0} = System.cmd("file", ["-ib", path])
    type =~ ~r/^text/i || type =~ ~r/ASCII/
  end

  ## File index

  @doc """
  The path of the cached file index for an upload.

  Lives in the upload's own directory, next to `dump.json`: nothing routes
  serve it, and it is not inside the unpacked tree the `_meta/unpacked`
  route can read.
  """
  def index_path(%Upload{} = upload) do
    upload
    |> Upload.upload_dir()
    |> Path.join(@index_name)
  end

  @doc """
  Returns `%{paths: [...], line_counts: %{...}}` for the upload's unpacked
  tree: every entry's path (the anchoring scope for line comments) and the
  line count of every file `read_data/1` would have attached text to.

  The result is cached on disk next to the upload and recomputed only when
  the cache is missing or when a fresh tree replaces the old one
  (`invalidate_index/1`). Uploads are immutable, so in the steady state
  this is one small file read, with no walk, no `file` forks, and no
  symlink risk, no matter how large the submission is.
  """
  def file_index(%Upload{} = upload) do
    case read_index(upload) do
      {:ok, index} -> index
      :error -> compute_and_persist_index(upload)
    end
  end

  @doc """
  Drops the cached index. Called when a fresh tree is extracted into the
  upload's unpacked path, so the next read rebuilds against the new tree.
  """
  def invalidate_index(%Upload{} = upload) do
    _ = File.rm(index_path(upload))
    :ok
  end

  defp read_index(upload) do
    with {:ok, json} <- File.read(index_path(upload)),
         {:ok, %{"paths" => paths, "line_counts" => counts}} <-
           Jason.decode(json) do
      {:ok, %{paths: paths, line_counts: counts}}
    else
      _ -> :error
    end
  end

  defp compute_and_persist_index(upload) do
    index = compute_index(Upload.unpacked_path(upload))

    # Temp file plus rename, so a concurrent reader never sees a partial
    # JSON file; two writers produce the same content anyway.
    tmp = "#{index_path(upload)}.#{System.unique_integer([:positive])}.tmp"
    File.write!(tmp, Jason.encode!(index))
    File.rename!(tmp, index_path(upload))

    index
  end

  @doc false
  def compute_index(base) do
    case File.lstat(base) do
      {:ok, %{type: :directory}} ->
        {paths, counts} = walk_index(base, "", {[], %{}})

        %{
          paths: Enum.sort([omega_name() | paths]),
          line_counts: Map.put(counts, omega_name(), omega_line_count())
        }

      _ ->
        %{paths: [], line_counts: %{}}
    end
  end

  # Walks the tree with `lstat`, mirroring which entries `read_data/1`
  # lists (every entry gets a path, so comments can anchor to a directory
  # exactly as before) but never following symlinks, so a cycle or a
  # directory link cannot multiply the walk.
  defp walk_index(base, rel, acc) do
    full = Path.join(base, rel)

    case File.lstat(full) do
      {:ok, %{type: :directory}} ->
        acc = add_index_path(acc, rel)

        Enum.reduce(File.ls!(full), acc, fn name, acc0 ->
          walk_index(base, Path.join(rel, name), acc0)
        end)

      {:ok, %{type: :regular, size: size}} ->
        acc
        |> add_index_path(rel)
        |> add_index_count(full, rel, size)

      {:ok, _} ->
        # Symlinks and anything else: the path exists but gets no line
        # count, matching the old walk which never read through links.
        add_index_path(acc, rel)

      {:error, _} ->
        add_index_path(acc, rel)
    end
  end

  defp add_index_path({paths, counts}, ""), do: {paths, counts}
  defp add_index_path({paths, counts}, rel), do: {[rel | paths], counts}

  # Line counts only for files the old text-walk would have produced one
  # for: inside `set_mode/3`'s size cap, not dot-named, and text. The
  # `file -ib` fork is replaced by a NUL-byte check so building the index
  # forks no subprocesses; the two agree on every file a grader can
  # meaningfully comment on.
  defp add_index_count(acc, _full, _rel, size) when size > @text_limit do
    acc
  end

  defp add_index_count({paths, counts}, full, rel, _size) do
    if dot_name?(rel) do
      {paths, counts}
    else
      case File.read(full) do
        {:ok, content} ->
          if :binary.match(content, <<0>>) == :nomatch do
            {paths, Map.put(counts, rel, count_newlines(content) + 1)}
          else
            {paths, counts}
          end

        {:error, _} ->
          {paths, counts}
      end
    end
  end

  defp dot_name?(rel) do
    rel |> Path.basename() |> String.starts_with?(".")
  end

  defp count_newlines(content) do
    content
    |> :binary.matches("\n")
    |> length()
  end
end
