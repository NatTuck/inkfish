defmodule InkfishWeb.Staff.BucketJSON do
  use InkfishWeb, :json

  alias Inkfish.Courses.Bucket
  alias InkfishWeb.Staff.AssignmentJSON

  def index(%{buckets: buckets}) do
    %{data: for(bucket <- buckets, do: data(bucket))}
  end

  def show(%{bucket: nil}), do: %{data: nil}

  def show(%{bucket: bucket}) do
    %{data: data(bucket)}
  end

  def data(nil), do: nil

  def data(%Bucket{} = bucket) do
    assignments = get_assoc(bucket, :assignments) || []

    %{
      id: bucket.id,
      name: bucket.name,
      assignments: for(asgn <- assignments, do: AssignmentJSON.data(asgn))
    }
  end
end
