defmodule InkfishWeb.Staff.GradeJSON do
  use InkfishWeb, :json

  alias Inkfish.Grades.Grade
  alias InkfishWeb.Staff.SubJSON
  alias InkfishWeb.Staff.GradeColumnJSON
  alias InkfishWeb.Staff.LineCommentJSON

  def index(%{grades: grades}) do
    %{data: for(grade <- grades, do: data(grade))}
  end

  def show(%{grade: nil}), do: %{data: nil}

  def show(%{grade: grade}) do
    %{data: data(grade)}
  end

  def data(nil), do: nil

  def data(%Grade{} = grade) do
    gc = get_assoc(grade, :grade_column)
    lcs = get_assoc(grade, :line_comments) || []
    sub = get_assoc(grade, :sub)

    %{
      id: grade.id,
      score: grade.score,
      sub_id: grade.sub_id,
      sub: SubJSON.data(sub),
      grade_column_id: grade.grade_column_id,
      grade_column: GradeColumnJSON.data(gc),
      line_comments: for(lc <- lcs, do: LineCommentJSON.data(lc))
    }
  end
end
