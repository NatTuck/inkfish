defmodule InkfishWeb.Staff.AttendanceJSON do
  use InkfishWeb, :json

  alias Inkfish.Attendances.Attendance

  def data(nil), do: nil

  def data(%Attendance{} = at) do
    %{
      meeting_id: at.meeting_id,
      reg_id: at.reg_id,
      status: at.status
    }
  end
end
