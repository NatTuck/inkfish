defmodule InkfishWeb.ApiV1.Staff.GradeController do
  use InkfishWeb, :controller

  alias Inkfish.Grades
  alias Inkfish.Grades.Grade
  alias Inkfish.Subs

  action_fallback InkfishWeb.FallbackController

  alias InkfishWeb.Plugs

  plug Plugs.RequireApiUser

  plug Plugs.FetchItem,
       [sub: "id"]
       when action in [:show]

  plug Plugs.FetchItem,
       [assignment: "assignment_id"]
       when action in [:index]

  plug Plugs.RequireReg, staff: true

  def index(conn, %{"sub_id" => sub_id}) do
    sub = Subs.get_sub_with_grades!(sub_id)
    render(conn, :index, grades: sub.grades)
  end

  def index(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "sub_id parameter is required"})
  end

  def create(conn, %{"grade" => grade_params}) do
    user = conn[:current_user]

    with {:ok, %Grade{} = grade} <-
           Grades.put_grade_with_comments(grade_params, user) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/staff/grades/#{grade}")
      |> render(:show, grade: grade)
    end
  end

  def show(conn, %{"id" => id}) do
    grade = Grades.get_grade!(id)
    render(conn, :show, grade: grade)
  end

  def delete(conn, %{"id" => id}) do
    grade = Grades.get_grade!(id)

    with {:ok, %Grade{}} <- Grades.delete_grade(grade) do
      send_resp(conn, :no_content, "")
    end
  end
end
