defmodule InkfishWeb.ApiV1.Staff.DashboardController do
  use InkfishWeb, :controller

  alias Inkfish.Assignments

  action_fallback InkfishWeb.FallbackController

  plug InkfishWeb.Plugs.RequireApiUser
  plug InkfishWeb.Plugs.RequireApiStaff

  def index(conn, _params) do
    staff_regs = conn.assigns[:current_staff_regs] || []

    if staff_regs == [] do
      conn
      |> put_view(InkfishWeb.ApiV1.Staff.DashboardJSON)
      |> render(:index, courses: [])
    else
      course_ids =
        Enum.map(staff_regs, fn reg -> reg.course_id end) |> Enum.uniq()

      past_assignments =
        Assignments.list_past_assignments_with_ungraded_subs(course_ids)

      upcoming_by_bucket =
        Assignments.list_all_buckets_with_upcoming(course_ids)

      courses =
        get_course_data(course_ids, past_assignments, upcoming_by_bucket)

      conn
      |> put_view(InkfishWeb.ApiV1.Staff.DashboardJSON)
      |> render(:index, courses: courses)
    end
  end

  defp get_course_data(course_ids, past_assignments, upcoming_by_bucket) do
    courses =
      Inkfish.Courses.list_courses()
      |> Enum.filter(fn c -> c.id in course_ids and not c.archived end)

    Enum.map(courses, fn course ->
      course_buckets =
        Inkfish.Courses.list_buckets(course.id) |> Enum.map(fn b -> b.name end)

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
