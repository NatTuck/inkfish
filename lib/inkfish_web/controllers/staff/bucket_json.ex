defmodule InkfishWeb.Staff.BucketJson do
  import InkfishWeb.ViewHelpers

  alias InkfishWeb.Staff.AssignmentJson

  def index(%{buckets: buckets}) do
    Enum.map(buckets, &data(%{bucket: &1}))
  end

  def data(%{bucket: bucket}) do
    assignments = get_assoc(bucket, :assignments) || []

    %{
      name: bucket.name,
      assignments: AssignmentJson.index(%{assignments: assignments})
    }
  end
end
