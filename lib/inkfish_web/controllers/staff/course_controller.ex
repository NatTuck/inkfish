defmodule InkfishWeb.Staff.CourseController do
  use InkfishWeb, :controller

  alias InkfishWeb.Plugs

  plug Plugs.FetchItem,
       [course: "id"]
       when action not in [:index]

  plug Plugs.RequireReg,
       [staff: true]
       when action not in [:index]

  plug InkfishWeb.Plugs.Breadcrumb, {"Courses (Staff)", :staff_course, :index}

  plug InkfishWeb.Plugs.Breadcrumb,
       {:show, :staff, :course}
       when action not in [:index, :new, :create]

  alias Inkfish.Courses
  alias Inkfish.Grades.Gradesheet
  alias Inkfish.GradingTasks
  alias Inkfish.Assignments.Assignment

  def index(conn, _params) do
    courses = Courses.list_courses()
    render(conn, "index.html", courses: courses)
  end

  def show(conn, %{"id" => id}) do
    reg = conn.assigns[:current_reg]
    course = Courses.get_course_for_staff_view!(id)
    task_count = GradingTasks.grader_course_task_count(course, reg)
    render(conn, "show.html", course: course, task_count: task_count)
  end

  def edit(conn, %{"id" => _id}) do
    course =
      conn.assigns[:course]
      |> Courses.reload_course_with_assignments!()

    assignments = list_assignments(course)
    changeset = Courses.change_course(course)

    render(conn, "edit.html",
      course: course,
      changeset: changeset,
      assignments: assignments
    )
  end

  def update(conn, %{"id" => _id, "course" => course_params}) do
    course = conn.assigns[:course]

    case Courses.update_course(course, course_params) do
      {:ok, course} ->
        conn
        |> put_flash(:info, "Course updated successfully.")
        |> redirect(to: ~p"/staff/courses/#{course}")

      {:error, %Ecto.Changeset{} = changeset} ->
        course =
          course
          |> Courses.reload_course_with_assignments!()

        assignments = list_assignments(course)

        render(conn, "edit.html",
          course: course,
          changeset: changeset,
          assignments: assignments
        )
    end
  end

  def gradesheet(conn, %{"id" => id}) do
    course = Courses.get_course_for_gradesheet!(id)
    sheet = Gradesheet.from_course(course)

    render(conn, "gradesheet.html",
      fluid_grid: true,
      course: course,
      sheet: sheet
    )
  end

  def tasks(conn, %{"id" => id}) do
    %{current_reg: reg} = conn.assigns

    course = Courses.get_course_for_grading_tasks!(id)

    tasks =
      course.buckets
      |> Enum.flat_map(fn bucket ->
        Enum.map(bucket.assignments, fn asg ->
          subs =
            Enum.filter(asg.subs, fn sub ->
              grade =
                Enum.find(sub.grades, &(&1.grade_column.kind == "feedback"))

              mine = !reg.is_grader || sub.grader_id == reg.id
              done = grade && grade.score
              sub.active && mine && !done
            end)

          {asg.id, length(subs)}
        end)
      end)
      |> Enum.into(%{})

    render(conn, "tasks.html", course: course, tasks: tasks)
  end

  defp list_assignments(course) do
    Enum.flat_map(course.buckets, fn bb ->
      Enum.map(bb.assignments, fn asg ->
        %Assignment{asg | bucket: bb}
      end)
    end)
  end
end
