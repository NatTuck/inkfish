defmodule Inkfish.Repo.Migrations.AddHardDeadlines do
  use Ecto.Migration

  def change do
    alter table("assignments") do
      add :hard_deadline, :boolean, null: false, default: false
      add :force_show_grades, :boolean, null: false, default: false
    end
  end
end
