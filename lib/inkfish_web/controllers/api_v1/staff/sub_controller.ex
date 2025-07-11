defmodule InkfishWeb.ApiV1.Staff.SubController do
  use InkfishWeb, :controller

  alias Inkfish.Assignments
  alias Inkfish.Subs
  alias Inkfish.Users

  action_fallback InkfishWeb.FallbackController

  plug InkfishWeb.Plugs.RequireApiUser

  def index(conn, params) do
    case Map.fetch(params, "assignment_id") do
      {:ok, asg_id_param} when is_binary(asg_id_param) and asg_id_param != "" ->
        asg_id = String.to_integer(asg_id_param)
        user = conn.assigns[:current_user]
        assignment = Assignments.get_assignment_path!(asg_id)
        course_id = assignment.bucket.course_id
        user_reg = Users.get_reg_by_user_and_course(user.id, course_id)

        if user_reg && (user_reg.is_staff || user_reg.is_prof) do
          page = Map.get(params, "page", "0") |> String.to_integer()
          subs = Subs.list_subs_for_api(asg_id, nil, page)

          conn
          |> put_view(InkfishWeb.ApiV1.SubJSON)
          |> render(:index, subs: subs)
        else
          conn
          |> put_status(:not_found)
          |> put_view(InkfishWeb.ErrorJSON)
          |> render(:not_found)
        end

      _ ->
        conn
        |> put_status(:bad_request)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:error,
          message: "assignment_id is required and must be a non-empty string"
        )
    end
  end

  def show(conn, %{"id" => id_str}) do
    user = conn.assigns[:current_user]
    id = String.to_integer(id_str)

    if sub = Subs.get_sub(id) do
      course_id = sub.assignment.bucket.course_id
      user_reg_in_course = Users.get_reg_by_user_and_course(user.id, course_id)

      is_staff_or_prof =
        user_reg_in_course &&
          (user_reg_in_course.is_staff || user_reg_in_course.is_prof)

      if is_staff_or_prof do
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
end
