defmodule InkfishWeb.ApiV1.Staff.DashboardJSON do
  use InkfishWeb, :json

  def index(%{courses: courses}) do
    %{courses: for(course <- courses, do: data(course))}
  end

  defp data(course) do
    %{
      id: course.id,
      name: course.name,
      past_assignments_with_ungraded:
        for(
          asg <- course.past_assignments_with_ungraded,
          do: past_assignment_data(asg)
        ),
      upcoming_by_bucket: course.upcoming_by_bucket
    }
  end

  defp past_assignment_data(asg) do
    %{
      id: asg.id,
      name: asg.name,
      due: asg.due,
      bucket_name: asg.bucket_name,
      course_id: asg.course_id,
      ungraded_count: asg.ungraded_count,
      total_count: asg.total_count,
      overdue: asg.overdue
    }
  end
end
