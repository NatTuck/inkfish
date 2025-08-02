defmodule InkfishWeb.ApiV1.Staff.GradeController do
  use InkfishWeb, :controller

  alias Inkfish.Grades
  alias Inkfish.Grades.Grade

  action_fallback InkfishWeb.FallbackController

  plug InkfishWeb.Plugs.RequireApiUser

  plug Plugs.FetchItem,
       [sub: "id"]
       when action in [:show]

  plug Plugs.FetchItem,
       [assignment: "assignment_id"]
       when action in [:index]

  plug Plugs.RequireReg, staff: true

  def index(conn, _params) do
    grades = Grades.list_grades()
    render(conn, :index, grades: grades)
  end

  def create(conn, %{"grade" => grade_params}) do
    with {:ok, %Grade{} = grade} <- Grades.create_grade(grade_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/api_v1/staff/grades/#{grade}")
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
