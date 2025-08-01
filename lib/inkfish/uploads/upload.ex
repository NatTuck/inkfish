defmodule Inkfish.Uploads.Upload do
  use Ecto.Schema
  import Ecto.Changeset

  alias Inkfish.Sandbox
  alias Inkfish.Uploads.Photo

  alias __MODULE__

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  @valid_kinds [
    "user_photo",
    "grade_column",
    "sub",
    "assignment_starter",
    "assignment_solution"
  ]

  schema "uploads" do
    field(:name, :string)
    field(:kind, :string)
    field(:size, :integer)
    belongs_to(:user, Inkfish.Users.User)

    has_one(:photo_user, Inkfish.Users.User, foreign_key: :photo_upload_id)

    has_one(:starter_assignment, Inkfish.Assignments.Assignment,
      foreign_key: :starter_upload_id
    )

    has_one(:solution_assignment, Inkfish.Assignments.Assignment,
      foreign_key: :solution_upload_id
    )

    has_many(:subs, Inkfish.Subs.Sub)

    field(:upload, :any, virtual: true)

    timestamps()
  end

  def parent(), do: :user

  @doc false
  def changeset(upload, attrs) do
    # Uploads are immutable, so all changesets are new inserts.
    upload
    |> cast(attrs, [:upload, :kind, :user_id])
    |> normalize_name()
    |> validate_required([:upload, :kind, :user_id, :name])
    |> validate_kind()
    |> validate_file_size()
    |> validate_required([:size])
  end

  def git_changeset(upload, attrs) do
    # Uploads are immutable, so all changesets are new inserts.
    upload
    |> cast(attrs, [:kind, :user_id, :name, :size])
    |> validate_required([:kind, :user_id, :name, :size])
    |> validate_kind()
  end

  def fake_changeset(upload, attrs) do
    # Uploads are immutable, so all changesets are new inserts.
    upload
    |> cast(attrs, [:kind, :user_id, :name])
    |> validate_required([:kind, :user_id, :name])
    |> validate_kind()
    |> put_change(:size, 10)
  end

  def copy_file!(upload, src) do
    File.copy!(src, upload_path(upload))
  end

  def normalize_name(%Ecto.Changeset{} = cset) do
    if upload = get_field(cset, :upload) do
      name = String.replace(upload.filename, ~r([^\w\.]+), "_")
      put_change(cset, :name, name)
    else
      cset
    end
  end

  def validate_kind(%Ecto.Changeset{} = cset) do
    kind = get_field(cset, :kind)

    if Enum.member?(@valid_kinds, kind) do
      cset
    else
      add_error(cset, :kind, "invalid upload kind: #{kind}")
    end
  end

  def validate_file_size(%Ecto.Changeset{} = cset) do
    upload = get_field(cset, :upload)

    if upload do
      size = file_size(upload.path)

      if size > 10_485_760 do
        add_error(cset, :upload, "uploaded file is too big")
      else
        put_change(cset, :size, size)
      end
    else
      cset
    end
  end

  def save_upload_file!(cset, %{kind: "user_photo"} = upload) do
    up = get_field(cset, :upload)
    Photo.resize_photo!(up.path, upload_path(upload), 960, 960)
    Photo.resize_photo!(upload_path(upload), Photo.thumb_path(upload), 200, 200)
  end

  def save_upload_file!(cset, upload) do
    up = get_field(cset, :upload)
    dst = upload_path(upload)
    _bs = File.copy!(up.path, dst)
    # IO.puts "Upload created copied #{bs} bytes to path '#{dst}'"
    if !File.exists?(dst) do
      IO.puts("Upload is missing.")
      raise "New upload missing"
    end
  end

  def save_upload_file!(_cset, upload, :fake) do
    path = Path.join(:code.priv_dir(:inkfish), "data/fake-upload.tar.gz")
    File.copy!(path, upload_path(upload))
  end

  def upload_path(upload) do
    upload_path(upload.id, upload.name)
  end

  def upload_path(id, name) do
    base = upload_dir(id)
    udir = Path.join(base, "upload")
    File.mkdir_p!(udir)
    Path.join(udir, name)
  end

  def unpacked_path(%Upload{} = upload) do
    base = upload_dir(upload.id)
    full = Path.join(base, "unpacked")
    File.mkdir_p!(full)
    full
  end

  def logs_path(upload) do
    base = upload_dir(upload.id)
    full = Path.join(base, "logs")
    File.mkdir_p!(full)
    full
  end

  def upload_dir(%Upload{id: id}) do
    upload_dir(id)
  end

  def upload_dir(uuid) do
    pre = String.slice(uuid, 0, 2)
    dir = Path.join(upload_base(), "#{pre}/#{uuid}")
    File.mkdir_p!(dir)
    dir
  end

  def upload_base() do
    env = Application.get_env(:inkfish, :env)
    Path.expand("~/.local/data/inkfish/uploads/#{env}")
  end

  def unpack(upload) do
    Sandbox.extract_archive(upload_path(upload), unpacked_path(upload))
  end

  def upload_url(nil), do: nil

  def upload_url(upload) do
    host = Application.get_env(:inkfish, :download_host)
    upload_url(host, upload)
  end

  def upload_url(host, upload) do
    "#{host}/uploads/#{upload.id}/#{upload.name}"
  end

  def fetch_size(upload) do
    size = file_size(upload_path(upload))
    %{upload | size: size}
  end

  def file_size(path) do
    info = File.stat!(path)
    info.size
  end
end
