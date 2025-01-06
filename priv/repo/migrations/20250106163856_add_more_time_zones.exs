defmodule Inkfish.Repo.Migrations.AddMoreTimeZones do
  use Ecto.Migration

  def change do
    alter table("team_members") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end
  end
end
