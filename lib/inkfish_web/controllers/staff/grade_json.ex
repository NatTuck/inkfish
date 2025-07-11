defmodule InkfishWeb.Staff.GradeJson do
  use InkfishWeb.Json
  alias InkfishWeb.Staff.SubJson
  alias InkfishWeb.Staff.GradeColumnJson
  alias InkfishWeb.Staff.LineCommentJson

  def index(%{grades: grades}) do
    %{data: Enum.map(grades, &data(%{grade: &1}))}
  end

  def show(%{grade: nil}), do: nil

  def show(%{grade: grade}) do
    %{data: data(%{grade: grade})}
  end

  def data(%{grade: grade}) do
    gc = get_assoc(grade, :grade_column)
    lcs = get_assoc(grade, :line_comments) || []
    sub = get_assoc(grade, :sub)

    %{
      id: grade.id,
      score: grade.score,
      sub_id: grade.sub_id,
      sub: SubJson.show(%{sub: sub}),
      grade_column_id: grade.grade_column_id,
      grade_column: GradeColumnJson.show(%{grade_column: gc}),
      line_comments: LineCommentJson.index(%{line_comments: lcs})
    }
  end
end
