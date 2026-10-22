defmodule Inkfish.Uploads do
  @moduledoc """
  The Uploads context.
  """

  require Logger

  import Ecto.Query, warn: false
  alias Inkfish.Repo

  alias Inkfish.Uploads.Upload
  alias Inkfish.Uploads.Cleanup

  @doc """
  Returns the list of uploads.

  ## Examples

      iex> list_uploads()
      [%Upload{}, ...]

  """
  def list_uploads do
    Repo.all(Upload)
    |> Repo.preload(:user)
  end

  @doc """
  Gets a single upload.

  Raises `Ecto.NoResultsError` if the Upload does not exist.

  ## Examples

      iex> get_upload!(123)
      %Upload{}

      iex> get_upload!(456)
      ** (Ecto.NoResultsError)

  """
  def get_upload!(id), do: Repo.get!(Upload, id)

  def get_upload(id) do
    id && Repo.get(Upload, id)
  end

  @doc """
  Creates a upload.

  ## Examples

      iex> create_upload(%{field: value})
      {:ok, %Upload{}}

      iex> create_upload(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_upload(attrs \\ %{}) do
    cset = Upload.changeset(%Upload{}, attrs)
    Cleanup.cleanup_user_uploads(attrs[:user_id], attrs[:kind])

    case Repo.insert(cset) do
      {:ok, upload} ->
        Upload.save_upload_file!(cset, upload)

        # The unpack must not be discarded: extracting past the tmpfs size cap
        # leaves a silently truncated tree behind, so a failure here has to
        # reach the caller instead of being reported as a success. The reason
        # rides on the changeset so callers keep the `{:error, changeset}`
        # shape they already handle for validation failures.
        #
        # NOTE: the row is already inserted at this point, so a failed unpack
        # leaves an orphaned upload row behind. That is pre-existing structure
        # on this path and is deliberately left alone.
        case Upload.unpack(upload) do
          :ok ->
            clean_uploads()
            {:ok, Upload.fetch_size(upload)}

          {:error, reason} ->
            {:error, unpack_error(cset, reason)}
        end

      error ->
        error
    end
  end

  def create_git_upload(attrs \\ %{}) do
    cset = Upload.git_changeset(%Upload{}, attrs)
    Cleanup.cleanup_user_uploads(attrs[:user_id], attrs[:kind])

    case Repo.insert(cset) do
      {:ok, upload} ->
        clean_uploads()
        {:ok, upload}

      error ->
        error
    end
  end

  # A direct-markdown submission is stored as an ordinary one-file upload, so
  # everything downstream -- the download link, the file viewer, line comments,
  # autograders and the cleanup sweep -- works on it with no special cases.
  #
  # Line endings are normalized to `\n` before the file is written. The text
  # comes from a browser textarea, where a form-encoded value would arrive with
  # `\r\n`, and the grader's line comments are numbered against the file: a
  # stray `\r` on every line would show up in the viewer and would not match
  # what the student typed.
  def create_text_upload(name, text, kind, user_id) do
    text = String.replace(text, "\r\n", "\n")

    # A private directory with an unguessable name, rather than a bare file in
    # the shared temp dir: the file holds the student's answer, and a
    # predictable path would let another local user read it, or plant a symlink
    # where it is about to be written.
    dir =
      Path.join(
        System.tmp_dir!(),
        "inkfish-text-upload-" <>
          Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
      )

    File.mkdir_p!(dir)
    File.chmod!(dir, 0o700)

    try do
      path = Path.join(dir, name)
      File.write!(path, text)

      # Atom keys on purpose: `create_upload/1` reads `attrs[:user_id]` and
      # `attrs[:kind]` to prune that user's unclaimed uploads, and string keys
      # silently skip it.
      create_upload(%{
        upload: %Plug.Upload{
          path: path,
          filename: name,
          content_type: "text/markdown"
        },
        kind: kind,
        user_id: user_id
      })
    after
      File.rm_rf(dir)
    end
  end

  def create_fake_upload(owner) do
    attrs = %{
      "user_id" => owner.id,
      "kind" => "sub",
      "name" => "fake-upload.tar.gz"
    }

    cset = Upload.fake_changeset(%Upload{}, attrs)

    case Repo.insert(cset) do
      {:ok, upload} ->
        Upload.save_upload_file!(cset, upload, :fake)

        case Upload.unpack(upload) do
          :ok ->
            {:ok, upload}

          {:error, reason} ->
            {:error, unpack_error(cset, reason)}
        end

      error ->
        error
    end
  end

  # A failed unpack is not a field-validation error produced by
  # `Upload.changeset/2`, but the changeset is what every caller of
  # `create_upload/1` already knows how to carry, and `:upload` is the virtual
  # field the changeset already reports upload errors against.
  # `Subs.create_sub_with_upload/2` rolls its transaction back on any
  # `{:error, _}` it gets.
  #
  # `reason` carries the raw mount/tar output, and it goes into the
  # user-facing text unchanged on purpose. Inkfish's users are computer science
  # students, so there is a good chance they understand a technical error and
  # can act on it: the specific reason is the only information they could have
  # used, and "could not unpack archive" on its own removes it. That is the
  # whole point of an error message, so this is a design choice, not a
  # concession.
  #
  # The output can therefore contain server paths. That is an accepted
  # consequence of showing the real error, not a defect -- do not "fix" it by
  # replacing the reason with something generic.
  defp unpack_error(cset, reason) do
    Logger.warning("upload unpack failed: #{format_reason(reason)}")

    Ecto.Changeset.add_error(
      cset,
      :upload,
      "could not unpack archive: " <> format_reason(reason)
    )
  end

  # `reason` is usually the mount/tar output as a binary, and that binary is
  # passed through verbatim -- not trimmed, summarised or replaced. Any other
  # term is `inspect`ed, so nothing is hidden there either.
  defp format_reason(reason) when is_binary(reason), do: reason

  defp format_reason(reason), do: inspect(reason)

  @doc """
  Updates a upload.

  ## Examples

      iex> update_upload(upload, %{field: new_value})
      {:ok, %Upload{}}

      iex> update_upload(upload, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_upload(%Upload{} = upload, attrs) do
    upload
    |> Upload.changeset(attrs)
    |> Repo.update()
    |> Repo.Cache.updated()
  end

  @doc """
  Deletes a Upload.

  ## Examples

      iex> delete_upload(upload)
      {:ok, %Upload{}}

      iex> delete_upload(upload)
      {:error, %Ecto.Changeset{}}

  """
  def delete_upload(%Upload{} = upload) do
    # IO.puts("Deleting upload:")
    # IO.inspect(upload)

    if upload.id do
      dpath = Upload.upload_dir(upload)

      if String.length(dpath) > 10 do
        File.rm_rf!(dpath)
        File.rmdir(Path.dirname(dpath))
      end

      Repo.delete(upload)
      |> Repo.Cache.updated()
    end
  end

  def clean_uploads() do
    if Application.get_env(:inkfish, :env) != :test do
      Task.start(fn ->
        Inkfish.Uploads.Cleanup.cleanup()
      end)
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking upload changes.

  ## Examples

      iex> change_upload(upload)
      %Ecto.Changeset{source: %Upload{}}

  """
  def change_upload(%Upload{} = upload) do
    Upload.changeset(upload, %{})
  end
end
