defmodule InkfishWeb.ApiV1.Staff.CourseJSON do
  use InkfishWeb, :json

  alias Inkfish.Courses.Course

  def show(%{course: course}) do
    %{data: data(course)}
  end

  defp data(%Course{} = course) do
    buckets =
      if Ecto.assoc_loaded?(course.buckets) do
        Enum.map(course.buckets, &bucket_data/1)
      else
        []
      end

    teamsets =
      if Ecto.assoc_loaded?(course.teamsets) do
        Enum.map(course.teamsets, &teamset_data/1)
      else
        []
      end

    %{
      id: course.id,
      name: course.name,
      solo_teamset_id: course.solo_teamset_id,
      buckets: buckets,
      teamsets: teamsets
    }
  end

  defp bucket_data(bucket) do
    %{
      id: bucket.id,
      name: bucket.name,
      weight: bucket.weight
    }
  end

  defp teamset_data(teamset) do
    %{
      id: teamset.id,
      name: teamset.name
    }
  end
end
