defmodule InkfishWeb.ApiV1.Staff.GradeJSON do
  use InkfishWeb, :json

  alias Inkfish.Grades.Grade
  alias InkfishWeb.Staff.GradeColumnJSON
  alias InkfishWeb.Staff.LineCommentJSON

  @doc """
  Renders a list of grades.
  """
  def index(%{grades: grades}) do
    %{data: for(grade <- grades, do: data(grade))}
  end

  @doc """
  Renders a single grade.
  """
  def show(%{grade: grade}) do
    %{data: data(grade)}
  end

  defp data(%Grade{} = grade) do
    grade_column = get_assoc(grade, :grade_column)

    line_comments =
      if Ecto.assoc_loaded?(grade.line_comments) do
        Enum.map(grade.line_comments, &LineCommentJSON.data/1)
      else
        []
      end

    %{
      id: grade.id,
      score: grade.score,
      grade_column_id: grade.grade_column_id,
      grade_column: GradeColumnJSON.data(grade_column),
      log_uuid: grade.log_uuid,
      line_comments: line_comments
    }
  end
end
