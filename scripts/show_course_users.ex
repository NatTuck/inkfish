defmodule ShowCourseUsers do
  alias Inkfish.Users
  alias Inkfish.Courses
  alias Inkfish.Repo

  def main(co_id) do
    course = Courses.get_course!(co_id)
    |> Repo.preload(regs: [:user])

    users = Enum.map(course.regs, &(&1.user))
   
    Enum.each users, fn user ->
      login = Regex.replace(~r/@.*$/, user.email, "")
      name = InkfishWeb.ViewHelpers.user_display_name(user)
      IO.puts("#{login}\t#{name}\t#{user.secret}")
    end
  end
end

argv = System.argv()

[co_id] = argv
{co_id, _} = Integer.parse(co_id)

ShowCourseUsers.main(co_id)
