defmodule InkfishWeb.ApiV1.SubController do
  use InkfishWeb, :controller1

  alias Inkfish.Subs
  alias Inkfish.Subs.Sub
  alias Inkfish.Assignments
  alias Inkfish.Users

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

  def create(conn, %{"sub" => sub_params}) do
    with {:ok, %Sub{} = sub} <- Subs.create_sub(sub_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/subs/#{sub}")
      # Use put_view
      |> put_view(InkfishWeb.ApiV1.SubJSON)
      # Use render/2
      |> render(:show, sub: sub)
    end
  end

  def show(conn, %{"id" => id_str}) do
    user = conn.assigns[:current_user]
    # Convert ID to integer. This might raise ArgumentError.
    id = String.to_integer(id_str)

    # This might raise Ecto.NoResultsError.
    sub = Subs.get_sub!(id)

    # Check if the current user is the submitter of this sub
    is_submitter = sub.reg.user_id == user.id

    # Check if the current user is staff/prof in the sub's course
    course_id = sub.assignment.bucket.course_id
    user_reg_in_course = Users.get_reg_by_user_and_course(user.id, course_id)

    is_staff_or_prof =
      user_reg_in_course &&
        (user_reg_in_course.is_staff || user_reg_in_course.is_prof)

    if is_submitter || is_staff_or_prof do
      conn
      # Use put_view
      |> put_view(InkfishWeb.ApiV1.SubJSON)
      # Use render/2
      |> render(:show, sub: sub)
    else
      # Deny access: return 404 Not Found to avoid leaking information about existing IDs
      conn
      |> put_status(:not_found)
      # Use put_view
      |> put_view(InkfishWeb.ErrorJSON)
      # Use render/2
      |> render(:not_found)
    end
  end
end
