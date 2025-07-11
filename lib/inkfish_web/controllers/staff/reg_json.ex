defmodule InkfishWeb.Staff.RegJson do
  use InkfishWeb.Json
  alias InkfishWeb.UserJson
  alias InkfishWeb.Staff.CourseJson

  def index(%{regs: regs}) do
    %{data: Enum.map(regs, &data(%{reg: &1}))}
  end

  def show(%{reg: nil}), do: nil

  def show(%{reg: reg}) do
    %{data: data(%{reg: reg})}
  end

  def data(%{reg: reg}) do
    user = get_assoc(reg, :user)
    course = get_assoc(reg, :course)

    %{
      id: reg.id,
      is_grader: reg.is_grader,
      is_staff: reg.is_staff,
      is_prof: reg.is_prof,
      is_student: reg.is_student,
      user_id: reg.user_id,
      user: UserJson.show(%{user: user}),
      course_id: reg.course_id,
      course: CourseJson.show(%{course: course}),
      section: reg.section
    }
  end
end
