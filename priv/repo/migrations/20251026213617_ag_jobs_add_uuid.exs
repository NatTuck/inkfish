defmodule Inkfish.Repo.Migrations.AgJobsAddUuid do
  use Ecto.Migration

  def change do
    alter table("ag_jobs") do
      add(:uuid, :string)
    end

    create unique_index(:ag_jobs, [:uuid])
  end
end
