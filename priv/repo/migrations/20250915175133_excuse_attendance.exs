defmodule Inkfish.Repo.Migrations.ExcuseAttendance do
  use Ecto.Migration

  def change do
    alter table(:attendances) do
      add :excused, :boolean, null: false, default: false
    end
  end
end
