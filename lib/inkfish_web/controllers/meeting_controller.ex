defmodule InkfishWeb.MeetingController do
  use InkfishWeb, :controller

  alias Inkfish.Meetings

  def index(conn, _params) do
    meetings = Meetings.list_meetings()
    render(conn, :index, meetings: meetings)
  end
end
