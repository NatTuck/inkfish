defmodule InkfishWeb.ApiV1.Staff.GradeJSON do
  use InkfishWeb, :json

  alias Inkfish.Grades.Grade
  alias Inkfish.LineComments
  alias InkfishWeb.Staff.GradeColumnJSON
  alias InkfishWeb.Staff.LineCommentJSON

  defp calculate_preview_score(%Grade{} = grade) do
    if Ecto.assoc_loaded?(grade.line_comments) &&
         Ecto.assoc_loaded?(grade.grade_column) do
      delta =
        Enum.reduce(grade.line_comments, Decimal.new("0.0"), fn lc, acc ->
          Decimal.add(lc.points, acc)
        end)

      Decimal.add(grade.grade_column.base, delta)
    else
      nil
    end
  end

  defp calculate_preview_score(_), do: nil

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

  @doc """
  Public function to render grade data. Can be called with just a grade struct.
  """
  def data(%Grade{} = grade) do
    data(grade, nil, nil)
  end

  defp data(%Grade{} = grade, valid_paths, valid_line_counts) do
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

    # Sort line comments by path then line number
    lcs = Enum.sort_by(lcs, &{&1.path, &1.line})

    preview_score = calculate_preview_score(grade)

    %{
      id: grade.id,
      score: grade.score,
      confirmed: grade.confirmed,
      preview_score: if(!grade.confirmed, do: preview_score, else: nil),
      grade_column_id: grade.grade_column_id,
      grade_column: GradeColumnJSON.data(grade_column),
      log_uuid: grade.log_uuid,
      line_comments: Enum.map(lcs, &LineCommentJSON.data/1)
    }
  end
end
