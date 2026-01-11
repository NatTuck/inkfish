defmodule Inkfish.Attendances.Report do
  alias Inkfish.Courses.Course
  alias Inkfish.Users.User
  alias Inkfish.Users.Reg
  alias Inkfish.Attendances.Attendance

  def build_attendance_report(%Course{} = course) do
    course = Inkfish.Courses.reload_course_for_attendance!(course)

    student_counts =
      for sreg <- course.regs do
        {User.display_name(sreg.user), attendance_score(sreg)}
      end

    {_name, par_score} =
      student_counts
      |> Enum.sort_by(fn {_name, score} -> score end)
      |> Enum.reverse()
      |> Enum.drop(2)
      |> hd()

    student_counts =
      for {name, score} <- student_counts do
        {name, score, round(100 * min(score / par_score, 1.0))}
      end

    meeting_count = length(course.meetings)

    %{
      meetings: meeting_count,
      perfect: 3 * meeting_count,
      students: student_counts,
      par_score: par_score
    }
  end

  def attendance_score(%Reg{} = reg) do
    Enum.sum_by(reg.attendances, fn at ->
      at = Attendance.put_status(at)
      at.points
    end)
  end
end
