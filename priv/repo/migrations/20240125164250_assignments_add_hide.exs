defmodule Inkfish.Repo.Migrations.AssignmentsAddHide do
  use Ecto.Migration

  def change do
    alter table("assignments") do
      add :hide, :boolean, default: false
    end
  end
end
