defmodule Inkfish.Repo.Migrations.AssignmentsAddAllowMarkdown do
  use Ecto.Migration

  def change do
    alter table(:assignments) do
      add :allow_markdown, :boolean, null: false, default: false
    end
  end
end
