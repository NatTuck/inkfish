defmodule Inkfish.DockerTags do
  @moduledoc """
  The DockerTags context.
  """

  import Ecto.Query, warn: false
  alias Inkfish.Repo

  alias Inkfish.DockerTags.DockerTag

  @doc """
  Returns the list of docker_tags.

  ## Examples

      iex> list_docker_tags()
      [%DockerTag{}, ...]

  """
  def list_docker_tags do
    Repo.all(DockerTag)
  end

  @doc """
  Gets a single docker_tag.

  Raises `Ecto.NoResultsError` if the Docker tag does not exist.

  ## Examples

      iex> get_docker_tag!(123)
      %DockerTag{}

      iex> get_docker_tag!(456)
      ** (Ecto.NoResultsError)

  """
  def get_docker_tag!(id), do: Repo.get!(DockerTag, id)
  def get_docker_tag(id), do: Repo.get(DockerTag, id)

  @doc """
  Creates a docker_tag.

  ## Examples

      iex> create_docker_tag(%{field: value})
      {:ok, %DockerTag{}}

      iex> create_docker_tag(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_docker_tag(attrs \\ %{}) do
    %DockerTag{}
    |> DockerTag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a docker_tag.

  ## Examples

      iex> update_docker_tag(docker_tag, %{field: new_value})
      {:ok, %DockerTag{}}

      iex> update_docker_tag(docker_tag, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_docker_tag(%DockerTag{} = docker_tag, attrs) do
    docker_tag
    |> DockerTag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a docker_tag.

  ## Examples

      iex> delete_docker_tag(docker_tag)
      {:ok, %DockerTag{}}

      iex> delete_docker_tag(docker_tag)
      {:error, %Ecto.Changeset{}}

  """
  def delete_docker_tag(%DockerTag{} = docker_tag) do
    Repo.delete(docker_tag)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking docker_tag changes.

  ## Examples

      iex> change_docker_tag(docker_tag)
      %Ecto.Changeset{data: %DockerTag{}}

  """
  def change_docker_tag(%DockerTag{} = docker_tag, attrs \\ %{}) do
    DockerTag.changeset(docker_tag, attrs)
  end

  alias Inkfish.Itty

  def build_dir(%DockerTag{} = dt) do
    text = dt.id
    |> to_string()
    |> String.pad_leading(6, "0")

    "~/.cache/inkfish/docker_tags/"
    |> Path.expand()
    |> Path.join(text)
  end

  def start_build(%DockerTag{} = dt) do
    dir = build_dir(dt)
    File.mkdir_p!(dir)

    Path.join(dir, "Dockerfile")
    |> File.write!(dt.dockerfile)

    Itty.run(~s[(cd "#{dir}" && docker build -t "#{dt.name}" .)])
  end

  def start_clean(%DockerTag{} = dt) do
    Itty.run(~s[(docker image rm "#{dt.name}" && docker image prune -f)])
  end

  def fresh_image?(%DockerTag{} = dt, nil), do: false
  def fresh_image?(%DockerTag{} = dt, %{"Created" => image_time}) do
    dt_time = dt.updated_at
    |> Inkfish.LocalTime.from_naive!()
    |> DateTime.to_unix()

    dt_time < image_time
  end
end
