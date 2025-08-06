defmodule InkfishWeb.MeetingController do
  use InkfishWeb, :controller

  alias Inkfish.Attendances

  alias InkfishWeb.Plugs

  plug Plugs.FetchItem, course: "course_id"

  plug Plugs.RequireReg

  alias InkfishWeb.Plugs.Breadcrumb
  plug Breadcrumb, {:show, :course}

  def index(conn, _params) do
    reg = conn.assigns[:current_reg]
    course = conn.assigns[:course]

    meetings = Attendances.list_attendances_by_meeting(course, reg)
    render(conn, :index, meetings: meetings)
  end
end
