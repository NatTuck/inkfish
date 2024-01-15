defmodule Inkfish.DockerTags.DockerTag do
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__
  alias Inkfish.Docker

  @timestamps_opts [type: :utc_datetime]

  schema "docker_tags" do
    field :dockerfile, :string
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(docker_tag, attrs) do
    docker_tag
    |> cast(attrs, [:name, :dockerfile])
    |> validate_required([:name, :dockerfile])
  end

  def default do
    %DockerTag{
      name: "inkfish:latest",
      dockerfile: Docker.default_dockerfile(),
    }
  end

  def build_dir(id) do
    text = id
    |> to_string()
    |> String.pad_leading(6, "0")

    "~/.cache/inkfish/docker_tags/"
    |> Path.expand()
    |> Path.join(text)
  end
end
