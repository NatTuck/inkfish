defmodule Import do
  alias Inkfish.Courses
  alias Inkfish.Courses.Course
  alias Inkfish.Users

  def set_user_section(course, email, sec) do
    user = Users.get_user_by_email!(email)
    {:ok, reg} = Users.find_reg(user, course)

    {:ok, _} = Users.update_reg(reg, %{"section" => sec})

    course = Courses.get_course!(course.id)

    sections = course
    |> Course.list_sections()
    |> MapSet.new()
    |> MapSet.put(sec)
    |> Enum.join(",")

    {:ok, _} = Courses.update_course(course, %{"sections" => sections})
  end

  def usnh_email(email) do
    upart = hd(String.split(email, "@"))
    "#{upart}@usnh.edu"
  end
  
  def main([course_id, roster_path]) do
    course = Courses.get_course!(course_id)
    data = File.stream!(roster_path)
    |> CSV.decode()
    |> Enum.drop(1)

    {:ok, _} = Courses.update_course(course, %{"sections" => "",})

    IO.inspect({course.name, roster_path})
    Enum.each data, fn {:ok, row} ->
      [_name, _, _, email, sec] = row
      set_user_section(course, usnh_email(email), sec)
      IO.inspect {email, sec}
    end
  end
end

Import.main(System.argv())
