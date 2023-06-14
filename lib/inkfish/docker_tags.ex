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
end
