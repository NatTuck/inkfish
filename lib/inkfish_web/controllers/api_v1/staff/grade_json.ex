defmodule InkfishWeb.ApiV1.Staff.GradeJSON do
  use InkfishWeb, :json

  alias Inkfish.Grades.Grade
  alias Inkfish.LineComments
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

  defp data(%Grade{} = grade, valid_paths \\ nil, valid_line_counts \\ nil) do
    grade_column = get_assoc(grade, :grade_column)

    lcs =
      if valid_paths && Ecto.assoc_loaded?(grade.line_comments) do
        {invalid_lcs, valid_lcs} =
          LineComments.filter_for_display(
            grade.line_comments,
            valid_paths,
            valid_line_counts
          )

        Enum.reverse(valid_lcs) ++ Enum.reverse(invalid_lcs)
      else
        if Ecto.assoc_loaded?(grade.line_comments) do
          grade.line_comments
        else
          []
        end
      end

    %{
      id: grade.id,
      score: grade.score,
      grade_column_id: grade.grade_column_id,
      grade_column: GradeColumnJSON.data(grade_column),
      log_uuid: grade.log_uuid,
      line_comments: Enum.map(lcs, &LineCommentJSON.data/1)
    }
  end
end
