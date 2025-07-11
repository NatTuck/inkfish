defmodule InkfishWeb.Staff.LineCommentJson do
  use InkfishWeb.Json
  alias InkfishWeb.UserJson
  alias InkfishWeb.Staff.GradeJson

  def render_list(line_comments) do
    index(%{line_comments: line_comments})
  end

  def index(%{line_comments: line_comments}) do
    %{data: Enum.map(line_comments, &data(%{line_comment: &1}))}
  end

  def show(%{line_comment: line_comment}) do
    %{data: data(%{line_comment: line_comment})}
  end

  def data(%{line_comment: line_comment}) do
    user = get_assoc(line_comment, :user)
    user_json = UserJson.show(%{user: user})

    grade = get_assoc(line_comment, :grade)
    grade_json = GradeJson.show(%{grade: grade})

    %{
      id: line_comment.id,
      path: line_comment.path,
      line: line_comment.line,
      points: line_comment.points,
      text: line_comment.text,
      user_id: line_comment.user_id,
      user: user_json,
      grade_id: line_comment.grade_id,
      grade: grade_json
    }
  end
end
