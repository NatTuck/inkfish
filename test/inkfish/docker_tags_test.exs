defmodule Inkfish.DockerTagsTest do
  use Inkfish.DataCase

  alias Inkfish.DockerTags

  describe "docker_tags" do
    alias Inkfish.DockerTags.DockerTag

    import Inkfish.DockerTagsFixtures

    @invalid_attrs %{dockerfile: nil, name: nil}

    test "list_docker_tags/0 returns all docker_tags" do
      docker_tag = docker_tag_fixture()
      assert DockerTags.list_docker_tags() == [docker_tag]
    end

    test "get_docker_tag!/1 returns the docker_tag with given id" do
      docker_tag = docker_tag_fixture()
      assert DockerTags.get_docker_tag!(docker_tag.id) == docker_tag
    end

    test "create_docker_tag/1 with valid data creates a docker_tag" do
      valid_attrs = %{dockerfile: "some dockerfile", name: "some name"}

      assert {:ok, %DockerTag{} = docker_tag} = DockerTags.create_docker_tag(valid_attrs)
      assert docker_tag.dockerfile == "some dockerfile"
      assert docker_tag.name == "some name"
    end

    test "create_docker_tag/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DockerTags.create_docker_tag(@invalid_attrs)
    end

    test "update_docker_tag/2 with valid data updates the docker_tag" do
      docker_tag = docker_tag_fixture()
      update_attrs = %{dockerfile: "some updated dockerfile", name: "some updated name"}

      assert {:ok, %DockerTag{} = docker_tag} = DockerTags.update_docker_tag(docker_tag, update_attrs)
      assert docker_tag.dockerfile == "some updated dockerfile"
      assert docker_tag.name == "some updated name"
    end

    test "update_docker_tag/2 with invalid data returns error changeset" do
      docker_tag = docker_tag_fixture()
      assert {:error, %Ecto.Changeset{}} = DockerTags.update_docker_tag(docker_tag, @invalid_attrs)
      assert docker_tag == DockerTags.get_docker_tag!(docker_tag.id)
    end

    test "delete_docker_tag/1 deletes the docker_tag" do
      docker_tag = docker_tag_fixture()
      assert {:ok, %DockerTag{}} = DockerTags.delete_docker_tag(docker_tag)
      assert_raise Ecto.NoResultsError, fn -> DockerTags.get_docker_tag!(docker_tag.id) end
    end

    test "change_docker_tag/1 returns a docker_tag changeset" do
      docker_tag = docker_tag_fixture()
      assert %Ecto.Changeset{} = DockerTags.change_docker_tag(docker_tag)
    end
  end
end
