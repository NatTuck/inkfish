defmodule InkfishWeb.Staff.GradeJSON do
  use InkfishWeb, :json

  alias Inkfish.Grades.Grade
  alias Inkfish.LineComments
  alias InkfishWeb.Staff.SubJSON
  alias InkfishWeb.Staff.GradeColumnJSON
  alias InkfishWeb.Staff.LineCommentJSON

  defp calculate_preview_score(%Grade{} = grade) do
    if Ecto.assoc_loaded?(grade.grade_column) &&
         Ecto.assoc_loaded?(grade.line_comments) do
      gcol = grade.grade_column
      lcs = grade.line_comments

      delta =
        Enum.reduce(lcs, Decimal.new("0.0"), fn lc, acc ->
          Decimal.add(lc.points, acc)
        end)

      Decimal.add(gcol.base, delta)
    else
      nil
    end
  end

  def index(%{grades: grades}) do
    %{data: for(grade <- grades, do: data(grade))}
  end

  def show(%{grade: nil}), do: %{data: nil}

  def show(%{grade: grade}) do
    %{data: data(grade)}
  end

  def data(nil), do: nil

  def data(%Grade{} = grade, valid_paths \\ nil, valid_line_counts \\ nil) do
    gc = get_assoc(grade, :grade_column)
    lcs = get_assoc(grade, :line_comments) || []
    sub = get_assoc(grade, :sub)

    {invalid_lcs, valid_lcs} =
      if valid_paths do
        LineComments.filter_for_display(lcs, valid_paths, valid_line_counts)
      else
        {[], lcs}
      end

    all_lcs = Enum.reverse(valid_lcs) ++ Enum.reverse(invalid_lcs)

    # Sort by path then line
    sorted_lcs = Enum.sort_by(all_lcs, &{&1.path, &1.line})

    preview_score =
      if !grade.confirmed, do: calculate_preview_score(grade), else: nil

    %{
      id: grade.id,
      score: grade.score,
      confirmed: grade.confirmed,
      preview_score: preview_score,
      sub_id: grade.sub_id,
      sub: SubJSON.data(sub),
      grade_column_id: grade.grade_column_id,
      grade_column: GradeColumnJSON.data(gc),
      line_comments: for(lc <- sorted_lcs, do: LineCommentJSON.data(lc))
    }
  end
end
