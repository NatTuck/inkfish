defmodule InkfishWeb.ApiV1.Staff.GradeController do
  use InkfishWeb, :controller

  alias Inkfish.Grades
  alias Inkfish.Grades.Grade
  alias Inkfish.Subs
  alias Inkfish.Subs.Sub

  action_fallback InkfishWeb.FallbackController

  alias InkfishWeb.Plugs

  plug Plugs.RequireApiUser

  plug Plugs.FetchItem,
       [grade: "id"]
       when action in [:show, :delete]

  plug Plugs.FetchItem,
       [sub: "sub_id"]
       when action in [:index, :create]

  plug Plugs.RequireReg, staff: true

  def index(conn, %{"sub_id" => sub_id}) do
    sub = Subs.get_sub_with_grades!(sub_id)
    render(conn, :index, grades: sub.grades)
  end

  def create(conn, %{"grade" => grade_params}) do
    user = conn.assigns[:current_user]
    sub = conn.assigns[:sub]

    # IO.inspect({:sub, sub})
    # IO.inspect({:params, grade_params})

    with {:ok, gcol} <- get_feedback_gcol(sub),
         params <- put_sub_and_gcol(grade_params, sub.id, gcol.id),
         {:ok, grade} <- Grades.put_grade_with_comments(params, user) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/staff/grades/#{grade}")
      |> render(:show, grade: grade)
    end
  end

  defp put_sub_and_gcol(params, sub_id, gcol_id) do
    params
    |> Map.put("sub_id", sub_id)
    |> Map.put("grade_column_id", gcol_id)
  end

  defp get_feedback_gcol(%Sub{} = sub) do
    gcol =
      Enum.find(sub.assignment.grade_columns, fn gc ->
        gc.kind == "feedback"
      end)

    if gcol do
      {:ok, gcol}
    else
      {:error, "No feedback grade column"}
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
