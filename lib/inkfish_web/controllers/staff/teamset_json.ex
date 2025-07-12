defmodule InkfishWeb.Staff.TeamsetJSON do
  use InkfishWeb, :json

  alias Inkfish.Teams.Teamset
  alias InkfishWeb.Staff.CourseJSON
  alias InkfishWeb.Staff.AssignmentJSON
  alias InkfishWeb.Staff.TeamJSON

  def index(%{teamsets: teamsets}) do
    %{data: for(teamset <- teamsets, do: data(teamset))}
  end

  def show(%{teamset: nil}), do: %{data: nil}

  def show(%{teamset: teamset}) do
    %{data: data(teamset)}
  end

  def data(nil), do: nil

  def data(%Teamset{} = teamset) do
    course = get_assoc(teamset, :course)
    assigns = get_assoc(teamset, :assignments) || []
    teams = get_assoc(teamset, :teams) || []

    %{
      id: teamset.id,
      name: teamset.name,
      course: CourseJSON.data(course),
      assignments: for(asgn <- assigns, do: AssignmentJSON.data(asgn)),
      teams: for(team <- teams, do: TeamJSON.data(team))
    }
  end
end
