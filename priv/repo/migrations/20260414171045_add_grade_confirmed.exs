defmodule Inkfish.Repo.Migrations.AddGradeConfirmed do
  use Ecto.Migration

  def change do
    alter table(:grades) do
      add :confirmed, :boolean, null: false, default: true
    end

    create index(:grades, [:sub_id, :confirmed])
  end
end
