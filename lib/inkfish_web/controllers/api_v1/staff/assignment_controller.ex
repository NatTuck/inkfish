defmodule InkfishWeb.ApiV1.Staff.AssignmentController do
  use InkfishWeb, :controller

  alias Inkfish.Assignments
  alias Inkfish.Assignments.Assignment
  alias Inkfish.Teams
  alias Inkfish.Courses.Bucket
  alias Inkfish.Repo

  action_fallback InkfishWeb.FallbackController

  alias InkfishWeb.Plugs

  plug InkfishWeb.Plugs.RequireApiUser

  plug Plugs.FetchItem,
       [assignment: "id"]
       when action in [:show]

  plug Plugs.FetchItem,
       [course: "course_id"]
       when action in [:create]

  plug Plugs.RequireReg, staff: true

  def create(conn, %{"course_id" => _course_id}) do
    course = conn.assigns[:course]

    assignment_params = conn.params["assignment"]

    bucket_id = Map.get(assignment_params, "bucket_id")

    case Repo.get(Bucket, bucket_id) do
      nil ->
        {:error, :not_found}

      bucket ->
        bucket = Repo.preload(bucket, :course)

        assignment_params =
          assignment_params
          |> Map.put("bucket_id", bucket.id)
          |> maybe_put_teamset_id(course)

        case Assignments.create_assignment(assignment_params) do
          {:ok, assignment} ->
            assignment =
              Assignment
              |> Repo.get!(assignment.id)
              |> Repo.preload([
                :bucket,
                :teamset,
                :grade_columns,
                :subs,
                :starter_upload,
                :solution_upload
              ])

            conn
            |> put_status(:created)
            |> put_view(InkfishWeb.Staff.AssignmentJSON)
            |> render(:show, assignment: assignment)

          {:error, %Ecto.Changeset{} = changeset} ->
            {:error, changeset}
        end
    end
  end

  defp maybe_put_teamset_id(params, course) do
    if Map.has_key?(params, "teamset_id") && params["teamset_id"] do
      params
    else
      teamset = Teams.get_solo_teamset!(course)
      Map.put(params, "teamset_id", teamset.id)
    end
  end

  def show(conn, _params) do
    asg =
      conn.assigns.assignment
      |> Assignments.preload_uploads()

    conn
    |> put_view(InkfishWeb.Staff.AssignmentJSON)
    |> render(:show, assignment: asg)
  end
end
