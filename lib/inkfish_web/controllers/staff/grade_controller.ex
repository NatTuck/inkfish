defmodule InkfishWeb.Staff.GradeController do
  use InkfishWeb, :controller

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
        render(conn, "grade.json", grade: grade)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_resp_header("content-type", "application/json; charset=UTF-8")
        |> send_resp(500, Jason.encode!(%{error: inspect(changeset)}))
    end
  end

  def show(conn, %{"id" => id}) do
    grade = Grades.get_grade!(id)
    render(conn, "show.html", grade: grade)
  end

  def edit(conn, %{"id" => id}) do
    {id, _} = Integer.parse(id)
    grade = Grades.get_grade!(id)
    rubric = Inkfish.Uploads.get_upload(grade.grade_column.upload_id)
    changeset = Grades.change_grade(grade)

    grade_json =
      InkfishWeb.Staff.GradeJSON.show(%{grade: grade})

    grader = conn.assigns[:current_user]
    grader_json = InkfishWeb.UserJSON.show(%{user: grader})

    data =
      Inkfish.Subs.read_sub_data(grade.sub_id)
      |> Map.put(:edit, true)
      |> Map.put(:grade_id, id)
      |> Map.put(:grade, grade_json)
      |> Map.put(:grader, grader_json)

    sub = Inkfish.Subs.get_sub!(grade.sub_id)

    render(conn, "edit.html",
      grade: grade,
      sub: sub,
      changeset: changeset,
      data: data,
      rubric: rubric
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

  def save_sub_dump!(sub_id) do
    Inkfish.Subs.save_sub_dump!(sub_id)
  end
end
