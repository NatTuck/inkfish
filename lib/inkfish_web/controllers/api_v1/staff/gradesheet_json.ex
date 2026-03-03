defmodule InkfishWeb.ApiV1.Staff.GradesheetJSON do
  use InkfishWeb, :json

  alias Inkfish.Users.User
  alias Inkfish.Courses.Course

  def gradesheet(%{course: course, sheet: sheet}) do
    %{
      course: course_data(course),
      students: student_data(course, sheet),
      buckets: bucket_data(course),
      stats: sheet.stats
    }
  end

  defp course_data(%Course{} = course) do
    %{
      id: course.id,
      name: course.name
    }
  end

  defp student_data(%Course{} = course, sheet) do
    Enum.reduce(course.regs, %{}, fn reg, acc ->
      name = User.display_name(reg.user)
      scores = sheet.students[reg.id]

      student_map = %{
        name: name,
        buckets: bucket_scores_data(course, scores)
      }

      Map.put(acc, reg.id, student_map)
    end)
  end

  defp bucket_scores_data(course, scores) do
    Enum.reduce(course.buckets, %{}, fn bucket, acc ->
      bs = scores.buckets[bucket.id]

      bucket_map = %{
        scores:
          Enum.reduce(bucket.assignments, %{}, fn as, inner_acc ->
            Map.put(inner_acc, as.id, as_score(bs.scores[as.id]))
          end),
        total: as_score(bs.total)
      }

      Map.put(acc, bucket.id, bucket_map)
    end)
  end

  defp bucket_data(%Course{} = course) do
    Enum.reduce(course.buckets, %{}, fn bucket, acc ->
      bucket_map = %{
        name: bucket.name,
        weight: bucket.weight,
        assignments: assignment_data(bucket.assignments)
      }

      Map.put(acc, bucket.id, bucket_map)
    end)
  end

  defp assignment_data(assignments) do
    Enum.reduce(assignments, %{}, fn as, acc ->
      Map.put(acc, as.id, %{
        name: as.name,
        weight: as.weight
      })
    end)
  end

  defp as_score(nil), do: nil
  defp as_score(dec) when is_binary(dec), do: dec

  defp as_score(dec) do
    Decimal.to_string(dec, :normal)
  end
end
