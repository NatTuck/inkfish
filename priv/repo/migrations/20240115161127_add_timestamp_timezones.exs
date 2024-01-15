defmodule Inkfish.Repo.Migrations.AddTimestampTimezones do
  use Ecto.Migration

  def change do
    alter table("assignments") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
      modify :due, :timestamptz, from: :timestamp
    end

    alter table("buckets") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end

    alter table("courses") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end

    alter table("docker_tags") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end

    alter table("grade_columns") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end

    alter table("grades") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end

    alter table("join_reqs") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end

    alter table("line_comments") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end

    alter table("regs") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end

    alter table("subs") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end

    alter table("teams") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end

    alter table("teamsets") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end

    alter table("uploads") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
    end

    alter table("users") do
      modify :inserted_at, :timestamptz, from: :timestamp
      modify :updated_at, :timestamptz, from: :timestamp
      modify :confirmed_at, :timestamptz, from: :timestamp
    end
  end
end
