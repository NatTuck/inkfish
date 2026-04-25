defmodule InkfishWeb.Staff.DashboardController do
  use InkfishWeb, :controller

  alias Inkfish.Assignments
  alias Inkfish.Courses

  plug InkfishWeb.Plugs.RequireStaff

  def index(conn, _params) do
    staff_regs = conn.assigns[:current_staff_regs] || []

    if staff_regs == [] do
      render(conn, "index.html", courses: [])
    else
      course_ids =
        Enum.map(staff_regs, fn reg -> reg.course_id end) |> Enum.uniq()

      past_assignments =
        Assignments.list_past_assignments_with_ungraded_subs(course_ids)

      upcoming_by_bucket =
        Assignments.list_all_buckets_with_upcoming(course_ids)

      courses =
        get_course_data(course_ids, past_assignments, upcoming_by_bucket)

      render(conn, "index.html", courses: courses)
    end
  end

  defp get_course_data(course_ids, past_assignments, upcoming_by_bucket) do
    courses =
      Courses.list_courses()
      |> Enum.filter(fn c -> c.id in course_ids and not c.archived end)

    Enum.map(courses, fn course ->
      course_buckets =
        Courses.list_buckets(course.id) |> Enum.map(fn b -> b.name end)

      course_past =
        Enum.filter(past_assignments, fn row ->
          row.course_id == course.id
        end)

      course_upcoming =
        Enum.reduce(course_buckets, %{}, fn bucket_name, acc ->
          Map.put(
            acc,
            bucket_name,
            Map.get(upcoming_by_bucket, bucket_name, [])
          )
        end)

      %{
        id: course.id,
        name: course.name,
        past_assignments_with_ungraded: course_past,
        upcoming_by_bucket: course_upcoming
      }
    end)
  end
end
