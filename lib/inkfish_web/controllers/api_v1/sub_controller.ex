defmodule InkfishWeb.ApiV1.SubController do
  use InkfishWeb, :controller1

  alias Inkfish.Subs
  alias Inkfish.Subs.Sub
  alias Inkfish.Assignments # Added alias for Assignments
  alias Inkfish.Users.Reg # Added alias for Reg

  action_fallback InkfishWeb.FallbackController

  plug InkfishWeb.Plugs.RequireApiUser

  def index(conn, %{"assignment_id" => asg_id} = params) do
    user = conn.assigns[:current_user]

    # Fetch the assignment to get its course_id
    # Use get_assignment_path! to ensure associated data (bucket, course) is loaded
    assignment = Assignments.get_assignment_path!(asg_id)
    course_id = assignment.bucket.course_id

    # Find the user's registration for this course
    user_reg = Reg.get_by_user_and_course(user.id, course_id)

    # Determine reg_id to filter by
    reg_id_filter =
      if Map.get(params, "all") && user_reg && (user_reg.is_staff || user_reg.is_prof) do
        nil # Staff/prof with 'all' param sees all subs for the assignment
      else
        user_reg && user_reg.id # Otherwise, filter by current user's reg_id (if they have one for this course)
      end

    # Handle pagination
    page = Map.get(params, "page", "0") |> String.to_integer() # Default to "0" string, then convert

    # Call Subs.list_subs_for_api
    subs = Subs.list_subs_for_api(asg_id, reg_id_filter, page)
    render(conn, :index, subs: subs)
  end

  def create(conn, %{"sub" => sub_params}) do
    with {:ok, %Sub{} = sub} <- Subs.create_sub(sub_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/subs/#{sub}")
      |> render(:show, sub: sub)
    end
  end

  def show(conn, %{"id" => id}) do
    sub = Subs.get_sub!(id)
    render(conn, :show, sub: sub)
  end

  def update(conn, %{"id" => id, "sub" => sub_params}) do
    sub = Subs.get_sub!(id)

    with {:ok, %Sub{} = sub} <- Subs.update_sub(sub, sub_params) do
      render(conn, :show, sub: sub)
    end
  end

  def delete(conn, %{"id" => id}) do
    sub = Subs.get_sub!(id)

    with {:ok, %Sub{}} <- Subs.delete_sub(sub) do
      send_resp(conn, :no_content, "")
    end
  end
end
