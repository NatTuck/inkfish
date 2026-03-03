defmodule InkfishWeb.ApiV1.Staff.CourseController do
  use InkfishWeb, :controller

  alias Inkfish.Repo
  alias Inkfish.Courses
  alias Inkfish.Grades.Gradesheet

  action_fallback InkfishWeb.FallbackController

  alias InkfishWeb.Plugs

  plug Plugs.RequireApiUser

  plug Plugs.FetchItem,
       [course: "id"]
       when action in [:show, :gradesheet]

  plug Plugs.RequireReg, staff: true

  def show(conn, %{"id" => _id}) do
    course =
      conn.assigns[:course]
      |> Repo.preload([:buckets, :teamsets, :solo_teamset])

    conn
    |> put_view(InkfishWeb.ApiV1.Staff.CourseJSON)
    |> render(:show, course: course)
  end

  def gradesheet(conn, %{"id" => id}) do
    course = Courses.get_course_for_gradesheet!(id)
    sheet = Gradesheet.from_course(course)

    conn
    |> put_view(InkfishWeb.ApiV1.Staff.GradesheetJSON)
    |> render(:gradesheet, course: course, sheet: sheet)
  end
end
