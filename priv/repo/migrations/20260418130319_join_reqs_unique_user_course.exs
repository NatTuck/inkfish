defmodule Inkfish.Repo.Migrations.JoinReqsUniqueUserCourse do
  use Ecto.Migration

  def change do
    create unique_index(:join_reqs, [:user_id, :course_id])
  end
end
