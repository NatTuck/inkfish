defmodule Inkfish.Repo.Migrations.AgJobsNonNullUuid do
  use Ecto.Migration

  def up do
    execute("DELETE FROM ag_jobs", "")

    alter table("ag_jobs") do
      modify(:uuid, :string, null: false)
    end

    drop index(:ag_jobs, [:sub_id])
    create unique_index(:ag_jobs, [:sub_id])
  end

  def down do
    drop unique_index(:ag_jobs, [:sub_id])
    create index(:ag_jobs, [:sub_id])

    alter table("ag_jobs") do
      modify(:uuid, :string, null: true)
    end
  end
end
