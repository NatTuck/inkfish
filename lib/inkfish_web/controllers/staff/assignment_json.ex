defmodule InkfishWeb.Staff.AssignmentJSON do
  use InkfishWeb, :json

  alias Inkfish.Assignments.Assignment
  alias InkfishWeb.Staff.BucketJSON
  alias InkfishWeb.Staff.TeamsetJSON
  alias InkfishWeb.Staff.GradeColumnJSON
  alias InkfishWeb.Staff.SubJSON

  def index(%{assignments: assignments}) do
    %{data: for(asgn <- assignments, do: data(asgn))}
  end

  def show(%{assignment: nil}), do: %{data: nil}

  def show(%{assignment: assignment}) do
    %{data: data(assignment)}
  end

  def data(nil), do: nil

  def data(%Assignment{} = assignment) do
    bucket = get_assoc(assignment, :bucket)
    teamset = get_assoc(assignment, :teamset)
    gcols = get_assoc(assignment, :grade_columns) || []
    subs = get_assoc(assignment, :subs) || []

    %{
      id: assignment.id,
      name: assignment.name,
      due: assignment.due,
      bucket: BucketJSON.data(bucket),
      teamset: TeamsetJSON.data(teamset),
      grade_columns: for(gcol <- gcols, do: GradeColumnJSON.data(gcol)),
      subs: for(sub <- subs, do: SubJSON.data(sub))
    }
  end
end
