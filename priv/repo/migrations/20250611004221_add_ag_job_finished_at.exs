defmodule Inkfish.Repo.Migrations.AddAgJobFinishedAt do
  use Ecto.Migration

  def change do
    alter table("ag_jobs") do
      add(:finished_at, :utc_datetime)
    end
  end
end
