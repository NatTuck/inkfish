defmodule Inkfish.Repo.Migrations.AddAttendanceAssignment do
  use Ecto.Migration

  def change do
    alter table("courses") do
      add :attendance_assignment_id,
          references(:assignments, on_delete: :nilify_all)
    end
  end
end
