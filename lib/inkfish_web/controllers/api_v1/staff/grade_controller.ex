defmodule InkfishWeb.ApiV1.Staff.GradeController do
  use InkfishWeb, :controller

  alias Inkfish.Grades
  alias Inkfish.Grades.GradeColumn
  alias Inkfish.Subs
  alias Inkfish.Subs.Sub

  action_fallback InkfishWeb.FallbackController

  alias InkfishWeb.Plugs

  plug Plugs.RequireApiUser

  plug Plugs.FetchItem,
       [grade: "id"]
       when action in [:show]

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

    with {:ok, gcol} <- get_grade_column(sub, grade_params),
         params <- build_grade_params(grade_params, sub.id, gcol),
         {:ok, grade} <- create_grade_for_column_kind(params, gcol, user) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/staff/grades/#{grade}")
      |> render(:show, grade: grade)
    end
  end

  defp get_grade_column(%Sub{} = sub, params) do
    case Map.get(params, "grade_column_id") do
      nil ->
        get_feedback_gcol(sub)

      gcol_id when is_binary(gcol_id) ->
        gcol_id = String.to_integer(gcol_id)
        gcol = Enum.find(sub.assignment.grade_columns, &(&1.id == gcol_id))

        if gcol do
          {:ok, gcol}
        else
          {:error, "Grade column not found"}
        end

      gcol_id when is_integer(gcol_id) ->
        gcol = Enum.find(sub.assignment.grade_columns, &(&1.id == gcol_id))

        if gcol do
          {:ok, gcol}
        else
          {:error, "Grade column not found"}
        end
    end
  end

  defp build_grade_params(params, sub_id, gcol) do
    params
    |> Map.put("sub_id", sub_id)
    |> Map.put("grade_column_id", gcol.id)
  end

  defp create_grade_for_column_kind(
         params,
         %GradeColumn{kind: "feedback"},
         user
       ) do
    if Map.has_key?(params, "score") do
      {:error,
       "Feedback grades are calculated automatically from line comments. Score cannot be set directly."}
    else
      Grades.put_grade_with_comments(params, user)
    end
  end

  defp create_grade_for_column_kind(params, %GradeColumn{kind: "number"}, _user) do
    if Map.has_key?(params, "score") do
      Grades.create_grade(params)
    else
      {:error, "Number grades require a score value"}
    end
  end

  defp create_grade_for_column_kind(_params, %GradeColumn{kind: kind}, _user) do
    {:error, "Grade column kind '#{kind}' is not supported via API"}
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
end
