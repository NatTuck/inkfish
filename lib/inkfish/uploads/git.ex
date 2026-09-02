defmodule Inkfish.Uploads.Git do
  alias Inkfish.Uploads
  alias Inkfish.Uploads.Upload

  @doc """
  Reads the cloned repository metadata (remote origin URL and commit SHA)
  from the unpacked checkout's `.git` directory. Returns `nil` when the
  checkout is not a git repository (e.g. a regular file upload).
  """
  def repo_info(unpacked_path) do
    with {:ok, url} <- repo_url(unpacked_path),
         {:ok, commit} <- repo_commit(unpacked_path) do
      %{url: url, commit: commit}
    else
      _ -> nil
    end
  end

  defp repo_url(unpacked_path) do
    config = Path.join([unpacked_path, ".git", "config"])

    with {:ok, text} <- File.read(config) do
      origin_url =
        text
        |> String.split("\n")
        |> parse_config_url()

      if origin_url, do: {:ok, origin_url}, else: :error
    else
      _ -> :error
    end
  end

  defp repo_commit(unpacked_path) do
    shallow = Path.join([unpacked_path, ".git", "shallow"])

    case File.read(shallow) do
      {:ok, text} ->
        case String.split(text) do
          [sha | _] -> {:ok, sha}
          _ -> :error
        end

      _ ->
        fetch_head = Path.join([unpacked_path, ".git", "FETCH_HEAD"])

        case File.read(fetch_head) do
          {:ok, text} ->
            case String.split(text) do
              [sha | _] -> {:ok, sha}
              _ -> :error
            end

          _ ->
            :error
        end
    end
  end

  defp parse_config_url(lines, in_origin? \\ false)

  defp parse_config_url([], _in_origin?), do: nil

  defp parse_config_url(["[" <> rest | tail], _in_origin?) do
    in_origin? = rest =~ ~r/^remote "origin"\]/
    parse_config_url(tail, in_origin?)
  end

  defp parse_config_url([line | tail], true) do
    case Regex.run(~r/^\s*url\s*=\s*(.+)$/, line) do
      [_, url] -> url
      _ -> parse_config_url(tail, true)
    end
  end

  defp parse_config_url([_line | tail], false) do
    parse_config_url(tail, false)
  end

  def start_clone(url) do
    script =
      :code.priv_dir(:inkfish)
      |> Path.join("scripts/upload_git_clone.sh")

    {:ok, _uuid} = Inkfish.Ittys.run(script, REPO: url, SIZE: "5m")
  end

  def get_results(uuid) do
    {:ok, view} = Inkfish.Ittys.close(uuid)
    parse_results(view.result)
  end

  @required_results ["dir", "tar"]

  def parse_results(text) do
    results =
      String.split(text, "\n", trim: true)
      |> Enum.reduce(%{}, fn line, acc ->
        case String.split(line, ~r/:\s*/, parts: 2) do
          [key, val] -> Map.put(acc, key, val)
          _ -> acc
        end
      end)

    if Enum.all?(@required_results, &Map.has_key?(results, &1)) do
      {:ok, results}
    else
      {:error, :incomplete_results}
    end
  end

  def create_upload(data, kind, user_id) do
    with {:ok, dir, tar} <- take_paths(data) do
      file_name = Path.basename(tar)
      size = Upload.file_size(tar)

      params = %{
        "kind" => kind,
        "user_id" => user_id,
        "name" => file_name,
        "size" => size
      }

      {:ok, upload} = Uploads.create_git_upload(params)

      File.cp!(tar, Upload.upload_path(upload))
      File.cp_r!(dir, Upload.unpacked_path(upload))

      {:ok, Upload.fetch_size(upload)}
    end
  end

  defp take_paths(data) do
    case {data["dir"], data["tar"]} do
      {dir, tar} when is_binary(dir) and is_binary(tar) -> {:ok, dir, tar}
      _ -> :error
    end
  end
end
