defmodule InkfishWeb.Staff.LineCommentJSON do
  use InkfishWeb, :json

  alias Inkfish.LineComments.LineComment
  alias InkfishWeb.UserJSON
  alias InkfishWeb.Staff.GradeJSON

  def index(%{line_comments: line_comments}) do
    %{data: for(lc <- line_comments, do: data(lc))}
  end

  def show(%{line_comment: nil}), do: %{data: nil}

  def show(%{line_comment: line_comment}) do
    %{data: data(line_comment)}
  end

  def data(nil), do: nil

  def data(%LineComment{} = line_comment) do
    user = get_assoc(line_comment, :user)
    grade = get_assoc(line_comment, :grade)

    %{
      id: line_comment.id,
      path: line_comment.path,
      line: line_comment.line,
      points: line_comment.points,
      text: line_comment.text,
      user_id: line_comment.user_id,
      user: UserJSON.data(user),
      grade_id: line_comment.grade_id,
      grade: GradeJSON.data(grade)
    }
  end
end
