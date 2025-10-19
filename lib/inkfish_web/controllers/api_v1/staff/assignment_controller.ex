defmodule InkfishWeb.ApiV1.Staff.AssignmentController do
  use InkfishWeb, :controller

  alias Inkfish.Assignments
  alias InkfishWeb.Plugs

  action_fallback InkfishWeb.FallbackController

  plug InkfishWeb.Plugs.RequireApiUser

  plug Plugs.FetchItem,
       [assignment: "id"]
       when action in [:show]

  plug Plugs.RequireReg, staff: true

  def show(conn, _params) do
    asg =
      conn.assigns.assignment
      |> Assignments.preload_uploads()

    conn
    |> put_view(InkfishWeb.Staff.AssignmentJSON)
    |> render(:show, assignment: asg)
  end
end
