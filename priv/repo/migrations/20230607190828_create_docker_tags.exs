defmodule Inkfish.Repo.Migrations.CreateDockerTags do
  use Ecto.Migration

  def change do
    create table(:docker_tags) do
      add :name, :string, null: false
      add :dockerfile, :text, null: false

      timestamps()
    end
  end
end
