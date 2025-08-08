defmodule InkfishWeb.MeetingJSON do
  alias Inkfish.Meetings.Meeting

  def data(nil), do: nil

  def data(%Meeting{} = meeting) do
    %{
      started_at: meeting.started_at,
      course_id: meeting.course_id
    }
  end
end
