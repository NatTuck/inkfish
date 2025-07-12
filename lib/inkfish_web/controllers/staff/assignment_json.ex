defmodule InkfishWeb.Staff.AssignmentJson do
  import InkfishWeb.ViewHelpers

  alias InkfishWeb.Staff.BucketJson
  alias InkfishWeb.Staff.TeamsetJson
  alias InkfishWeb.Staff.GradeColumnJson
  alias InkfishWeb.Staff.SubJson

  def index(%{assignments: assignments}) do
    Enum.map(assignments, &data(%{assignment: &1}))
  end

  def data(%{assignment: assignment}) do
    bucket = get_assoc(assignment, :bucket)
    teamset = get_assoc(assignment, :teamset)
    gcols = get_assoc(assignment, :grade_columns)
    subs = get_assoc(assignment, :subs) || []

    %{
      name: assignment.name,
      due: assignment.due,
      bucket: BucketJson.data(%{bucket: bucket}),
      teamset: TeamsetJson.show(%{teamset: teamset}),
      grade_columns: GradeColumnJson.index(%{grade_columns: gcols}),
      subs: SubJson.index(%{subs: subs})
    }
  end
end
