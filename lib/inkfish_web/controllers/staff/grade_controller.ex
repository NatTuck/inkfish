defmodule InkfishWeb.Staff.GradeController do
  use InkfishWeb, :controller

  import Ecto.Query

  alias Inkfish.Grades

  plug InkfishWeb.Plugs.FetchItem,
       [grade: "id"]
       when action not in [:index, :new, :create]

  plug InkfishWeb.Plugs.FetchItem,
       [sub: "sub_id"]
       when action in [:index, :new, :create]

  plug InkfishWeb.Plugs.RequireReg, staff: true

  alias InkfishWeb.Plugs.Breadcrumb
  plug Breadcrumb, {"Courses (Staff)", :staff_course, :index}
  plug Breadcrumb, {:show, :staff, :course}
  plug Breadcrumb, {:show, :staff, :assignment}
  plug Breadcrumb, {:show, :staff, :sub}

  def create(conn, %{"sub_id" => sub_id, "grade" => grade_params}) do
    grade_params =
      grade_params
      |> Map.put("sub_id", sub_id)
      |> Map.put("grading_user_id", conn.assigns[:current_user_id])

    if conn.assigns[:client_mode] == :browser do
      browser_create(conn, %{"grade" => grade_params})
    else
      ajax_create(conn, %{"grade" => grade_params})
    end
  end

  def browser_create(conn, %{"grade" => grade_params}) do
    case Grades.create_grade(grade_params) do
      {:ok, grade} ->
        Inkfish.Subs.calc_sub_score!(grade.sub_id)
        save_sub_dump!(grade.sub_id)
        redirect(conn, to: ~p"/staff/grades/#{grade.id}/edit")

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_flash(:error, "Failed to create grade.")
        |> redirect(to: ~p"/dashboard")
    end
  end

  def ajax_create(conn, %{"grade" => grade_params}) do
    case Grades.create_grade(grade_params) do
      {:ok, grade} ->
        Inkfish.Subs.calc_sub_score!(grade.sub_id)
        save_sub_dump!(grade.sub_id)

        grade_json =
          InkfishWeb.Staff.GradeJSON.data(grade)

        conn
        |> put_resp_header("content-type", "application/json; charset=UTF-8")
        |> send_resp(201, Jason.encode!(%{data: grade_json}))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_resp_header("content-type", "application/json; charset=UTF-8")
        |> send_resp(500, Jason.encode!(%{error: inspect(changeset)}))
    end
  end

  def show(conn, %{"id" => id}) do
    grade =
      Grades.get_grade!(id)
      |> Inkfish.Repo.preload(grade_column: [:assignment])

    render(conn, "show.html", grade: grade)
  end

  def edit(conn, %{"id" => id}) do
    {id, _} = Integer.parse(id)
    grade = Grades.get_grade!(id)
    rubric = Inkfish.Uploads.get_upload(grade.grade_column.upload_id)
    changeset = Grades.change_grade(grade)

    sub = Inkfish.Subs.get_sub!(grade.sub_id)
    sub_data = Inkfish.Subs.read_sub_data(grade.sub_id)

    # The comment anchoring scopes come from the upload's cached file
    # index; the tree read is only the viewer payload. Deriving both from
    # the tree meant a `file` fork per file on every page load, and the
    # walk did not terminate on a symlink cycle (#154).
    index = Inkfish.Uploads.Data.file_index(sub.upload)
    valid_paths = index.paths
    valid_line_counts = index.line_counts

    grade_json =
      InkfishWeb.Staff.GradeJSON.data(grade, valid_paths, valid_line_counts)

    grader = conn.assigns[:current_user]
    grader_json = InkfishWeb.UserJSON.data(grader)

    data =
      sub_data
      |> Map.put(:edit, true)
      |> Map.put(:grade_id, id)
      |> Map.put(:grade, grade_json)
      |> Map.put(:grader, grader_json)

    git =
      Inkfish.Uploads.Git.repo_info(
        Inkfish.Uploads.Upload.unpacked_path(sub.upload)
      )

    render(conn, "edit.html",
      fluid_grid: true,
      grade: grade,
      sub: sub,
      changeset: changeset,
      data: data,
      rubric: rubric,
      git: git
    )
  end

  def update(conn, %{"id" => id, "grade" => grade_params}) do
    grade = Grades.get_grade!(id)

    case Grades.update_grade(grade, grade_params) do
      {:ok, grade} ->
        Inkfish.Subs.calc_sub_score!(grade.sub_id)
        save_sub_dump!(grade.sub_id)

        conn
        |> put_flash(:info, "Grade updated successfully.")
        |> redirect(to: ~p"/staff/grades/#{grade}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", grade: grade, changeset: changeset)
    end
  end

  def confirm_review(conn, %{"id" => id}) do
    {id, _} = Integer.parse(id)
    grade = Grades.get_grade!(id)

    # Preload necessary associations
    grade =
      Inkfish.Repo.preload(grade, [
        :grade_column,
        :line_comments,
        sub: [:upload]
      ])

    # Get line comments with context
    unpacked_path = Inkfish.Uploads.Upload.unpacked_path(grade.sub.upload)

    comments_with_context =
      grade.line_comments
      |> Enum.sort_by(&{&1.path, &1.line})
      |> Enum.with_index()
      |> Enum.map(fn {lc, index} ->
        context = get_line_context(unpacked_path, lc.path, lc.line)

        stats =
          get_comment_usage_stats(
            grade.grade_column.assignment_id,
            lc.path,
            lc.line,
            lc.text
          )

        %{comment: lc, context: context, stats: stats, index: index}
      end)

    # Calculate preview score
    preview_score = InkfishWeb.ViewHelpers.show_preview_score(grade)

    # Serialize comments for React widgets
    comments_json =
      comments_with_context
      |> Enum.map(fn %{comment: lc} ->
        InkfishWeb.Staff.LineCommentJSON.data(lc)
      end)

    next_grade =
      if grade.confirmed do
        nil
      else
        Grades.next_grade_for_review(grade, conn.assigns.current_reg)
      end

    render(conn, "confirm_review.html",
      grade: grade,
      comments_with_context: comments_with_context,
      preview_score: preview_score,
      comments_json: comments_json,
      grade_confirmed: grade.confirmed,
      next_grade: next_grade,
      csrf_token: Plug.CSRFProtection.get_csrf_token()
    )
  end

  def confirm(conn, %{"id" => id} = params) do
    {id, _} = Integer.parse(id)

    case Grades.confirm_grade(id) do
      {:ok, grade} ->
        next =
          if params["next"] in ["true", "1"] do
            Grades.next_grade_for_review(grade, conn.assigns.current_reg)
          end

        target =
          if next do
            ~p"/staff/grades/#{next.id}/confirm-review"
          else
            ~p"/staff/grades/#{grade}"
          end

        conn
        |> put_flash(:info, "Grade confirmed successfully.")
        |> redirect(to: target)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Grade not found.")
        |> redirect(to: ~p"/dashboard")
    end
  end

  def unconfirm(conn, %{"id" => id}) do
    {id, _} = Integer.parse(id)

    case Grades.unconfirm_grade(id) do
      {:ok, grade} ->
        conn
        |> put_flash(:info, "Grade unlocked for editing.")
        |> redirect(to: ~p"/staff/grades/#{grade}/edit")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Grade not found.")
        |> redirect(to: ~p"/dashboard")
    end
  end

  defp get_line_context(unpacked_path, file_path, line_number) do
    Inkfish.LineComments.Context.get(unpacked_path, file_path, line_number)
  end

  defp get_comment_usage_stats(assignment_id, path, line, text) do
    # Count how many other submissions have similar comments
    from(lc in Inkfish.LineComments.LineComment,
      join: grade in assoc(lc, :grade),
      join: gcol in assoc(grade, :grade_column),
      join: sub in assoc(grade, :sub),
      where: gcol.assignment_id == ^assignment_id,
      where: lc.path == ^path,
      where: lc.line == ^line,
      where: lc.text == ^text,
      select: count(sub.id)
    )
    |> Inkfish.Repo.one()
  end

  def save_sub_dump!(sub_id) do
    Inkfish.Subs.save_sub_dump!(sub_id)
  end
end
