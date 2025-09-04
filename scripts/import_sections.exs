defmodule Import do
  alias Inkfish.Courses
  alias Inkfish.Courses.Course
  alias Inkfish.Users

  def get_or_create_user(name, email) do
    try do
      Users.get_user_by_email!(email)
    rescue
      _ ->
        name_parts = Regex.split(~r/\s+/, name)
        first = hd(name_parts)
        last = hd(Enum.reverse(name_parts))

        pass = :crypto.strong_rand_bytes(8) |> Base.encode16()
        
        attrs = %{
          email: email,
          password: pass,
          password_confirmation: pass,
          given_name: first,
          surname: last,
          is_admin: false
        }
        IO.inspect({:create_user, attrs})
        {:ok, user} = Users.create_user(attrs)
        user 
    end
  end

  def get_or_create_reg(user, course) do
    case Users.find_reg(user, course) do
      {:ok, reg} -> 
        reg
      _ ->
        attrs = %{
          "is_student" => true,
          "user_id" => user.id,
          "course_id" => course.id,
        }
        IO.inspect({:create_reg, attrs})
        {:ok, reg} = Inkfish.Users.create_reg(attrs)
        reg
    end
  end

  def set_user_section(course, [name, _, _, email, sec]) do
    email = usnh_email(email)
    user = get_or_create_user(name, email)
    reg = get_or_create_reg(user, course)

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
      set_user_section(course, row)
      IO.inspect(row)
    end
  end
end

Import.main(System.argv())
