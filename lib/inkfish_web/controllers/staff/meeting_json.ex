defmodule InkfishWeb.Staff.MeetingJSON do
  use InkfishWeb, :json

  alias Inkfish.Meetings.Meeting

  alias InkfishWeb.AttendanceJSON
  alias InkfishWeb.Staff.TeamsetJSON

  def data(nil), do: nil

  def data(%Meeting{} = mm) do
    attendances = get_assoc(mm, :attendances) || []
    teamset = get_assoc(mm, :teamset)

    %{
      started_at: mm.started_at,
      secret_code: mm.secret_code,
      attendances: for(at <- attendances, do: AttendanceJSON.data(at)),
      teamset: TeamsetJSON.data(teamset)
    }
  end
end
