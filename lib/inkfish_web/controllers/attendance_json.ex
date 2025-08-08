defmodule InkfishWeb.AttendanceJSON do
  alias Inkfish.Attendances.Attendance

  def data(nil), do: nil

  def data(%Attendance{} = attendance) do
    %{
      reg_id: attendance.reg_id,
      meeting_id: attendance.meeting_id,
      attended_at: attendance.attended_at,
      status: attendance.status
    }
  end
end
