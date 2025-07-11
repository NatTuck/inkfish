defmodule InkfishWeb.ApiV1.SubController do
  use InkfishWeb, :controller1

  alias Inkfish.Subs
  alias Inkfish.Assignments
  alias Inkfish.Users
  alias Inkfish.Teams

  action_fallback InkfishWeb.FallbackController

  plug InkfishWeb.Plugs.RequireApiUser

  # There are intentinally no update or delete functions
  # here; do not add them.

  def index(conn, params) do
    case Map.fetch(params, "assignment_id") do
      {:ok, asg_id_param} when is_binary(asg_id_param) and asg_id_param != "" ->
        # Convert to integer for lookup. This might raise ArgumentError.
        asg_id = String.to_integer(asg_id_param)

        user = conn.assigns[:current_user]

        # Fetch the assignment to get its course_id. This might raise Ecto.NoResultsError.
        assignment = Assignments.get_assignment_path!(asg_id)
        course_id = assignment.bucket.course_id

        # Find the user's registration for this course
        user_reg = Users.get_reg_by_user_and_course(user.id, course_id)

        # Determine reg_id to filter by
        reg_id_filter =
          if Map.get(params, "all") && user_reg &&
               (user_reg.is_staff || user_reg.is_prof) do
            # Staff/prof with 'all' param sees all subs for the assignment
            nil
          else
            # Otherwise, filter by current user's reg_id (if they have one for this course)
            user_reg && user_reg.id
          end

        # Handle pagination
        # Default to "0" string, then convert
        page = Map.get(params, "page", "0") |> String.to_integer()

        # Call Subs.list_subs_for_api
        subs = Subs.list_subs_for_api(asg_id, reg_id_filter, page)

        conn
        # Use put_view
        |> put_view(InkfishWeb.ApiV1.SubJSON)
        # Use render/2
        |> render(:index, subs: subs)

      # assignment_id is missing, empty string, or not a binary
      _ ->
        conn
        |> put_status(:bad_request)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:error,
          message: "assignment_id is required and must be a non-empty string"
        )
    end
  end

  @doc """
  This accepts a request with an x-auth header simulating
  a form like this:

  <form type="multipart">
    <input name="sub[upload]" type="file">
    <input name="sub[assignment_id]">
    <input name="sub[hours_spent]">
  </form>
  """
  def create(conn, %{"sub" => sub_params}) do
    user = conn.assigns[:current_user]

    with {:ok, asg_id} <- fetch_key(sub_params, "assignment_id"),
         {:ok, upload} <- fetch_key(sub_params, "upload"),
         asg when not is_nil(asg) <- Assignments.get_assignment_path(asg_id) do
      reg = Users.find_reg(user, asg.bucket.course)
      team = Teams.get_active_team(asg, reg)

      sub_params =
        sub_params
        |> Map.put("team_id", team.id)
        |> Map.put("reg_id", reg.id)

      upload_params = %{
        "upload" => upload,
        "user_id" => user.id
      }

      case Subs.create_sub_with_upload(sub_params, upload_params) do
        {:ok, sub} ->
          conn
          |> put_status(:created)
          |> put_view(InkfishWeb.ApiV1.SubJSON)
          |> render(:show, sub: sub)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(InkfishWeb.ChangesetJSON)
          |> render(:error, changeset: changeset)
      end
    else
      nil ->
        conn
        |> put_status(:bad_request)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:error, message: "assignment_id not found")

      {:error, key} ->
        conn
        |> put_status(:bad_request)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:error, message: "#{key} is required")
    end
  end

  def show(conn, %{"id" => id_str}) do
    user = conn.assigns[:current_user]
    id = String.to_integer(id_str)

    if sub = Subs.get_sub(id) do
      is_submitter = sub.reg.user_id == user.id

      if is_submitter do
        conn
        |> put_view(InkfishWeb.ApiV1.SubJSON)
        |> render(:show, sub: sub)
      else
        conn
        |> put_status(:not_found)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:not_found)
      end
    else
      conn
      |> put_status(:not_found)
      |> put_view(InkfishWeb.ErrorJSON)
      |> render(:not_found)
    end
  end

  defp fetch_key(map, key) do
    case Map.fetch(map, key) do
      {:ok, val} -> {:ok, val}
      :error -> {:error, key}
    end
  end
end
