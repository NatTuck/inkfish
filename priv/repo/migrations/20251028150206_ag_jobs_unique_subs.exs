defmodule Inkfish.Repo.Migrations.AgJobsUniqueSubs do
  use Ecto.Migration

  def change do
    # Delete all existing ag jobs
    execute("DELETE FROM ag_jobs", "")
    
    # Drop the existing index on sub_id
    drop index(:ag_jobs, [:sub_id])
    
    # Create a new unique index on sub_id
    create unique_index(:ag_jobs, [:sub_id])
  end
end
