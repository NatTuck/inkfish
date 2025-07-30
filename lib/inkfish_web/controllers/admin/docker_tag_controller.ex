defmodule InkfishWeb.Admin.DockerTagController do
  use InkfishWeb, :controller

  alias Inkfish.Sandbox.Containers
  alias Inkfish.DockerTags
  alias Inkfish.DockerTags.DockerTag

  def index(conn, _params) do
    docker_tags = DockerTags.list_docker_tags()
    render(conn, :index, docker_tags: docker_tags)
  end

  def new(conn, _params) do
    base = DockerTag.default()
    changeset = DockerTags.change_docker_tag(base)
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"docker_tag" => docker_tag_params}) do
    case DockerTags.create_docker_tag(docker_tag_params) do
      {:ok, docker_tag} ->
        conn
        |> put_flash(:info, "Docker tag created successfully.")
        |> redirect(to: ~p"/admin/docker_tags/#{docker_tag}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    docker_tag = DockerTags.get_docker_tag!(id)

    case Containers.get_image_by_tag(docker_tag.name) do
      {:error, ee} ->
        conn
        |> put_flash(:error, inspect(ee))
        |> redirect(to: ~p"/admin/docker_tags")

      image ->
        fresh = DockerTags.fresh_image?(docker_tag, image)
        render(conn, :show, docker_tag: docker_tag, image: image, fresh: fresh)
    end
  end

  def edit(conn, %{"id" => id}) do
    docker_tag = DockerTags.get_docker_tag!(id)
    changeset = DockerTags.change_docker_tag(docker_tag)
    render(conn, :edit, docker_tag: docker_tag, changeset: changeset)
  end

  def update(conn, %{"id" => id, "docker_tag" => docker_tag_params}) do
    docker_tag = DockerTags.get_docker_tag!(id)

    case DockerTags.update_docker_tag(docker_tag, docker_tag_params) do
      {:ok, docker_tag} ->
        conn
        |> put_flash(:info, "Docker tag updated successfully.")
        |> redirect(to: ~p"/admin/docker_tags/#{docker_tag}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, docker_tag: docker_tag, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    docker_tag = DockerTags.get_docker_tag!(id)
    {:ok, _docker_tag} = DockerTags.delete_docker_tag(docker_tag)

    conn
    |> put_flash(:info, "Docker tag deleted successfully.")
    |> redirect(to: ~p"/admin/docker_tags")
  end

  def build(conn, %{"id" => id}) do
    tag = DockerTags.get_docker_tag!(id)
    {:ok, uuid} = DockerTags.start_build(tag)
    render(conn, :build, id: id, docker_tag: tag, uuid: uuid)
  end

  def clean(conn, %{"id" => id}) do
    tag = DockerTags.get_docker_tag!(id)
    {:ok, uuid} = DockerTags.start_clean(tag)
    render(conn, :build, id: id, docker_tag: tag, uuid: uuid)
  end
end
