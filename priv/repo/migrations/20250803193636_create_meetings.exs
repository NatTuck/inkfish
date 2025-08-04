defmodule Inkfish.Repo.Migrations.CreateMeetings do
  use Ecto.Migration

  def change do
    create table(:meetings) do
      add :started_at, :utc_datetime, null: false
      add :secret_code, :string, null: false
      add :course_id, references(:courses, on_delete: :nothing), null: false
      add :teamset_id, references(:teamsets, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:meetings, [:course_id])
    create index(:meetings, [:teamset_id])
  end
end
