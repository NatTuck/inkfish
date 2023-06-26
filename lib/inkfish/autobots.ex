defmodule Inkfish.Autobots do
  alias Inkfish.Autobots.Autograde
  alias Inkfish.Autobots.Queue

  alias Inkfish.Grades
  alias Inkfish.Grades.Grade
  alias Inkfish.Subs
  alias Inkfish.Subs.Sub
  
  def autograde(%Grade{} = grade) do
    grade = Grades.get_grade_for_autograding!(grade.id)
    Autograde.autograde(grade)
  end

  def autograde_sub(%Sub{} = sub) do
    Enum.each Subs.get_script_grades(sub), fn grade ->
      autograde(grade)
    end
  end
  def autograde_sub(sub_id) do
    Subs.get_sub!(sub_id)
    |> autograde_sub()
  end
end
