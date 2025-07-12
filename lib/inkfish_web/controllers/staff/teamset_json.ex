defmodule InkfishWeb.Staff.TeamsetJson do
  import InkfishWeb.ViewHelpers

  alias InkfishWeb.Staff.CourseJson
  alias InkfishWeb.Staff.AssignmentJson
  alias InkfishWeb.Staff.TeamJson

  def show(%{teamset: nil}), do: nil

  def show(%{teamset: teamset}) do
    %{data: data(%{teamset: teamset})}
  end

  def data(%{teamset: teamset}) do
    course = get_assoc(teamset, :course)
    assigns = get_assoc(teamset, :assignments) || []
    teams = get_assoc(teamset, :teams) || []

    %{
      id: teamset.id,
      name: teamset.name,
      course: CourseJson.show(%{course: course}),
      assignments: AssignmentJson.index(%{assignments: assigns}),
      teams: TeamJson.index(%{teams: teams})
    }
  end
end
