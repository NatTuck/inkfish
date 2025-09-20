defmodule InkfishWeb.Staff.SubController do
  use InkfishWeb, :controller

  alias InkfishWeb.Plugs

  plug Plugs.FetchItem,
       [sub: "id"]
       when action not in [:index, :new, :create]

  plug Plugs.FetchItem,
       [assignment: "assignment_id"]
       when action in [:index, :new, :create]

  plug Plugs.RequireReg, staff: true

  alias InkfishWeb.Plugs.Breadcrumb
  plug Breadcrumb, {"Courses (Staff)", :staff_course, :index}
  plug Breadcrumb, {:show, :staff, :course}
  plug Breadcrumb, {:show, :staff, :assignment}

  alias Inkfish.Subs
  alias Inkfish.Teams
  alias Inkfish.Grades.Grade
  alias Inkfish.Assignments

  alias InkfishWeb.Staff

  def show(conn, %{"id" => id}) do
    sub = Subs.get_sub!(id)
    sub = %{sub | team: Teams.get_team!(sub.team_id)}
    sub_data = InkfishWeb.Staff.SubJSON.show(%{sub: sub})

    autogrades =
      Subs.get_or_create_script_grades(sub)
      |> Enum.map(fn grade ->
        grade = %{grade | sub: sub}
        log = Grade.get_log(grade)
        token = Phoenix.Token.sign(conn, "autograde", %{uuid: grade.log_uuid})
        {grade, token, log}
      end)

    render(conn, "show.html",
      sub: sub,
      sub_data: sub_data,
      autogrades: autogrades
    )
  end

  def update(conn, %{"id" => _id, "sub" => params}) do
    # Limited operations allowed:
    #  - Set or clear grader

    sub = conn.assigns[:sub]

    if params["grader_id"] do
      Subs.update_sub_grader(sub, params["grader_id"])
    end

    if conn.assigns[:client_mode] == :browser do
      conn
      |> put_flash(:info, "Updated sub flags: ##{sub.id}.")
      |> redirect(to: ~p"/staff/subs/#{sub}")
    else
      asg = Assignments.get_assignment_for_grading_tasks!(sub.assignment_id)
      data = Staff.AssignmentJSON.show(%{assignment: asg})

      conn
      |> put_resp_header("content-type", "application/json; charset=UTF-8")
      |> send_resp(200, Jason.encode!(%{assignment: data}))
    end
  end

  def activate(conn, %{"id" => _id}) do
    sub = conn.assigns[:sub]
    Subs.set_sub_active!(sub)

    conn
    |> put_flash(:info, "Set sub active: ##{sub.id}.")
    |> redirect(to: ~p"/staff/subs/#{sub}")
  end

  def toggle_late_penalty(conn, %{"id" => _id}) do
    sub = conn.assigns[:sub]

    Subs.update_sub_ignore_late(sub, %{
      "ignore_late_penalty" => !sub.ignore_late_penalty
    })

    conn
    |> put_flash(:info, "Toggle ingore late for sub: ##{sub.id}.")
    |> redirect(to: ~p"/staff/subs/#{sub}")
  end
end
