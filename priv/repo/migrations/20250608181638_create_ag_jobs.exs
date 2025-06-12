defmodule Inkfish.Repo.Migrations.CreateAgJobs do
  use Ecto.Migration

  def change do
    create table(:ag_jobs) do
      add :dupkey, :string, null: false
      add :prio, :integer, null: false
      add :started_at, :utc_datetime
      add :sub_id, references(:subs, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:ag_jobs, [:sub_id])
    create index(:ag_jobs, [:dupkey])
  end
end
