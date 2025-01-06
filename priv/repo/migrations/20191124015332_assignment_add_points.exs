defmodule Inkfish.Repo.Migrations.AssignmentAddPoints do
  use Ecto.Migration

  def up do
    alter table("assignments") do
      add :points, :decimal, null: false, default: "0.0"
    end
  end

  def down do
    alter table("assignments") do
      # :decimal, null: false, default: "0.0"
      remove :points
    end
  end
end
