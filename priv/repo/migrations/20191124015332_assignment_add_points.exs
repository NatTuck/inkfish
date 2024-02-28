defmodule Inkfish.Repo.Migrations.AssignmentAddPoints do
  use Ecto.Migration

  def up do
    alter table("assignments") do
      add :points, :decimal, null: false, default: "0.0"
    end
  end

  def down do
    alter table("assignments") do
      remove :points # :decimal, null: false, default: "0.0"
    end
  end
end
