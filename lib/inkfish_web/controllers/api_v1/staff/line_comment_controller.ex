defmodule InkfishWeb.ApiV1.Staff.LineCommentController do
  use InkfishWeb, :controller

  alias Inkfish.LineComments
  alias Inkfish.LineComments.LineComment
  alias InkfishWeb.Plugs

  action_fallback InkfishWeb.FallbackController

  plug InkfishWeb.Plugs.RequireApiUser

  plug Plugs.FetchItem,
       [grade: "grade_id"]
       when action in [:create]

  plug Plugs.FetchItem,
       [line_comment: "id"]
       when action in [:show, :update, :delete]

  plug Plugs.RequireReg, staff: true

  def create(conn, %{"grade_id" => grade_id, "line_comment" => comment_params}) do
    user = conn.assigns[:current_user]

    params =
      comment_params
      |> Map.put("grade_id", grade_id)
      |> Map.put("user_id", user.id)

    case LineComments.create_line_comment(params, :auto, :auto) do
      {:ok, %LineComment{} = comment} ->
        conn
        |> put_status(:created)
        |> render(:show, line_comment: comment)

      {:error, :grade_already_confirmed} ->
        conn
        |> put_status(:forbidden)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:error, message: "grade_already_confirmed")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(InkfishWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  def show(conn, _params) do
    comment = conn.assigns.line_comment
    render(conn, :show, line_comment: comment)
  end

  def update(conn, %{"id" => id, "line_comment" => comment_params}) do
    comment = LineComments.get_line_comment!(id)

    case LineComments.update_line_comment(comment, comment_params) do
      {:ok, %LineComment{} = updated_comment} ->
        render(conn, :show, line_comment: updated_comment)

      {:error, :grade_already_confirmed} ->
        conn
        |> put_status(:forbidden)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:error, message: "grade_already_confirmed")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(InkfishWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    comment = LineComments.get_line_comment!(id)

    case LineComments.delete_line_comment(comment) do
      {:ok, %LineComment{} = deleted_comment} ->
        render(conn, :show, line_comment: deleted_comment)

      {:error, :grade_already_confirmed} ->
        conn
        |> put_status(:forbidden)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:error, message: "grade_already_confirmed")
    end
  end
end
