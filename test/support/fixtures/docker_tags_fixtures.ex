defmodule Inkfish.DockerTagsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Inkfish.DockerTags` context.
  """

  @doc """
  Generate a docker_tag.
  """
  def docker_tag_fixture(attrs \\ %{}) do
    {:ok, docker_tag} =
      attrs
      |> Enum.into(%{
        dockerfile: "some dockerfile",
        name: "some name"
      })
      |> Inkfish.DockerTags.create_docker_tag()

    docker_tag
  end
end
