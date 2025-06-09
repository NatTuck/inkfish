defmodule Inkfish.Repo.Migrations.AddGradeColumnLimits do
  use Ecto.Migration

  def change do
    alter table("grade_columns") do
      add :limits, :string
    end
  end
end
