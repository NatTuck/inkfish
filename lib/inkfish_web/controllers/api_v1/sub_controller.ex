defmodule InkfishWeb.ApiV1.SubController do
  use InkfishWeb, :controller1

  alias Inkfish.Subs
  alias Inkfish.Subs.Sub
  alias Inkfish.Assignments
  alias Inkfish.Users

  action_fallback InkfishWeb.FallbackController

  plug InkfishWeb.Plugs.RequireApiUser

  def index(conn, params) do
    # Explicitly check for assignment_id
    unless Map.has_key?(params, "assignment_id") do
      # Return a 400 Bad Request if assignment_id is missing
      conn
      |> put_status(:bad_request)
      |> put_view(InkfishWeb.ErrorJSON) # Use put_view
      |> render(:error, message: "assignment_id is required") # Use render/2
      |> halt() # Halt execution
    end

    asg_id = params["assignment_id"]
    user = conn.assigns[:current_user]

    # Fetch the assignment to get its course_id
    # Use get_assignment_path! to ensure associated data (bucket, course) is loaded
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
    |> put_view(InkfishWeb.ApiV1.SubJSON) # Use put_view
    |> render(:index, subs: subs) # Use render/2
  end

  def create(conn, %{"sub" => sub_params}) do
    with {:ok, %Sub{} = sub} <- Subs.create_sub(sub_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/subs/#{sub}")
      |> put_view(InkfishWeb.ApiV1.SubJSON) # Use put_view
      |> render(:show, sub: sub) # Use render/2
    end
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns[:current_user]

    # get_sub! preloads reg, assignment, bucket, and course
    sub = Subs.get_sub!(id)

    # Check if the current user is the submitter of this sub
    is_submitter = sub.reg.user_id == user.id

    # Check if the current user is staff/prof in the sub's course
    course_id = sub.assignment.bucket.course_id
    user_reg_in_course = Users.get_reg_by_user_and_course(user.id, course_id)
    is_staff_or_prof = user_reg_in_course && (user_reg_in_course.is_staff || user_reg_in_course.is_prof)

    if is_submitter || is_staff_or_prof do
      conn
      |> put_view(InkfishWeb.ApiV1.SubJSON) # Use put_view
      |> render(:show, sub: sub) # Use render/2
    else
      # Deny access: return 404 Not Found to avoid leaking information about existing IDs
      conn
      |> put_status(:not_found)
      |> put_view(InkfishWeb.ErrorJSON) # Use put_view
      |> render(:not_found) # Use render/2
    end
  end

  def update(conn, %{"id" => id, "sub" => sub_params}) do
    sub = Subs.get_sub!(id)

    with {:ok, %Sub{} = sub} <- Subs.update_sub(sub, sub_params) do
      conn
      |> put_view(InkfishWeb.ApiV1.SubJSON) # Use put_view
      |> render(:show, sub: sub) # Use render/2
    end
  end

  # Removed the delete/2 function as subs cannot be deleted via the API.
end
