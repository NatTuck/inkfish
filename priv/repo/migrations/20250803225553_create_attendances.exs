defmodule Inkfish.Repo.Migrations.CreateAttendances do
  use Ecto.Migration

  def change do
    create table(:attendances) do
      add :attended_at, :utc_datetime, null: false
      add :meeting_id, references(:meetings, on_delete: :nothing), null: false
      add :reg_id, references(:regs, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:attendances, [:meeting_id])
    create index(:attendances, [:reg_id])
  end
end
