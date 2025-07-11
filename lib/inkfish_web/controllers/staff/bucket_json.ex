defmodule InkfishWeb.Staff.BucketJson do
  use InkfishWeb.ViewHelpers

  alias InkfishWeb.Staff.AssignmentView

  def data(%{bucket: bucket}) do
    assignments = get_assoc(bucket, :assignments) || []

    %{
      name: bucket.name,
      assignments: render_many(assignments, AssignmentView, "assignment.json")
    }
  end
end
