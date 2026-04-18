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

    sub_data = Inkfish.Subs.read_sub_data(grade.sub_id)
    valid_paths = extract_path_keys(sub_data.files)
    valid_line_counts = extract_line_counts(sub_data.files)

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

    sub = Inkfish.Subs.get_sub!(grade.sub_id)

    render(conn, "edit.html",
      fluid_grid: true,
      grade: grade,
      sub: sub,
      changeset: changeset,
      data: data,
      rubric: rubric
    )
  end

  defp extract_path_keys(%{nodes: nodes}) do
    extract_path_keys(nodes, [])
  end

  defp extract_path_keys(files) when is_list(files) do
    extract_path_keys(files, [])
  end

  defp extract_path_keys([], acc), do: acc

  defp extract_path_keys([%{key: key, nodes: nodes} | rest], acc) do
    acc = [key | acc]
    acc = extract_path_keys(nodes ++ rest, acc)
    extract_path_keys(rest, acc)
  end

  defp extract_path_keys([%{key: key} | rest], acc) do
    extract_path_keys(rest, [key | acc])
  end

  defp extract_line_counts(%{nodes: nodes}) do
    build_line_counts_map(nodes, %{})
  end

  defp build_line_counts_map([], acc), do: acc

  defp build_line_counts_map([%{key: key, text: text} | rest], acc)
       when is_binary(text) do
    line_count = String.split(text, "\n") |> length()
    build_line_counts_map(rest, Map.put(acc, key, line_count))
  end

  defp build_line_counts_map([%{nodes: nodes} | rest], acc) do
    acc = build_line_counts_map(nodes, acc)
    build_line_counts_map(rest, acc)
  end

  defp build_line_counts_map([_ | rest], acc) do
    build_line_counts_map(rest, acc)
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
    _sub_data = Inkfish.Subs.read_sub_data(grade.sub_id)
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

    render(conn, "confirm_review.html",
      grade: grade,
      comments_with_context: comments_with_context,
      preview_score: preview_score,
      comments_json: comments_json,
      grade_confirmed: grade.confirmed,
      csrf_token: Plug.CSRFProtection.get_csrf_token()
    )
  end

  def confirm(conn, %{"id" => id}) do
    {id, _} = Integer.parse(id)

    case Grades.confirm_grade(id) do
      {:ok, grade} ->
        conn
        |> put_flash(:info, "Grade confirmed successfully.")
        |> redirect(to: ~p"/staff/grades/#{grade}")

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
    file_path = Path.join(unpacked_path, file_path)

    if File.exists?(file_path) do
      content = File.read!(file_path)
      lines = String.split(content, "\n")

      # Get +/- 2 lines around the comment
      start_line = max(1, line_number - 2)
      end_line = min(length(lines), line_number + 2)

      lines
      |> Enum.slice(start_line - 1, end_line - start_line + 1)
      |> Enum.with_index(start_line)
      |> Enum.map(fn {text, num} ->
        %{line: num, text: text, is_commented: num == line_number}
      end)
    else
      []
    end
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
