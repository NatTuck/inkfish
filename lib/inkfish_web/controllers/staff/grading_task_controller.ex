defmodule InkfishWeb.Staff.GradingTaskController do
  use InkfishWeb, :controller

  alias InkfishWeb.Plugs
  plug Plugs.FetchItem, assignment: "assignment_id"
  plug Plugs.RequireReg, staff: true

  alias InkfishWeb.Plugs.Breadcrumb
  plug Breadcrumb, {"Courses (Staff)", :staff_course, :index}
  plug Breadcrumb, {:show, :staff, :course}
  plug Breadcrumb, {:show, :staff, :assignment}

  alias Inkfish.Assignments
  alias Inkfish.Courses

  def show(conn, _params) do
    %{course: course, assignment: as, current_reg: reg} = conn.assigns

    graders = Courses.list_course_graders(course)

    tasks = Assignments.list_grading_tasks(as)

    user_tasks =
      Enum.filter(tasks, fn sub ->
        sub.grader_id == reg.id
      end)

    render(conn, "show.html",
      graders: graders,
      tasks: tasks,
      user_tasks: user_tasks
    )
  end

  def create(conn, _params) do
    %{assignment: as} = conn.assigns

    :ok = Inkfish.GradingTasks.assign_grading_tasks(as)

    conn
    |> put_flash(:info, "Grading has been assigned.")
    |> redirect(to: ~p"/staff/assignments/#{as}/grading_tasks")
  end

  def edit(conn, _params) do
    %{course: course, assignment: as} = conn.assigns

    graders =
      Courses.list_course_graders(course)
      |> Enum.map(fn gdr ->
        InkfishWeb.Staff.RegJSON.show(%{reg: gdr})
      end)
      |> Jason.encode!()

    asg =
      Assignments.get_assignment_for_grading_tasks!(as.id)
      |> (fn arg ->
            InkfishWeb.Staff.AssignmentJSON.show(%{assignment: arg})
          end).()
      |> Jason.encode!()

    render(conn, "edit.html", graders: graders, asg: asg)
  end

  def update(conn, _params) do
    %{assignment: as} = conn.assigns

    conn
    |> put_flash(:error, "TODO: Update grading")
    |> redirect(to: ~p"/staff/assignments/#{as}/grading_tasks")
  end
end
