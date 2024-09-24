defmodule Inkfish.Repo.Migrations.AddCourseSections do
  use Ecto.Migration

  def change do
    alter table("courses") do
      add :sections, :string, null: false, default: ""
    end

    alter table("regs") do
      add :section, :string
    end
  end
end