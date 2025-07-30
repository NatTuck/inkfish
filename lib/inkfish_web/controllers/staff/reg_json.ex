defmodule InkfishWeb.Staff.RegJSON do
  use InkfishWeb, :json

  alias Inkfish.Users.Reg
  alias InkfishWeb.UserJSON
  alias InkfishWeb.Staff.CourseJSON

  def index(%{regs: regs}) do
    %{data: for(reg <- regs, do: data(reg))}
  end

  def show(%{reg: nil}), do: %{data: nil}

  def show(%{reg: reg}) do
    %{data: data(reg)}
  end

  def data(nil), do: nil

  def data(%Reg{} = reg) do
    user = get_assoc(reg, :user)
    course = get_assoc(reg, :course)

    %{
      id: reg.id,
      is_grader: reg.is_grader,
      is_staff: reg.is_staff,
      is_prof: reg.is_prof,
      is_student: reg.is_student,
      user_id: reg.user_id,
      user: UserJSON.data(user),
      course_id: reg.course_id,
      course: CourseJSON.data(course),
      section: reg.section
    }
  end
end
