defmodule InkfishWeb.GradeController do
  use InkfishWeb, :controller

  alias Inkfish.Grades

  alias InkfishWeb.Plugs

  plug Plugs.FetchItem,
       [grade: "id"]
       when action not in [:index, :new, :create]

  plug Plugs.RequireReg

  plug Plugs.RequireSubmitter
       when action in [:show]

  alias InkfishWeb.Plugs.Breadcrumb
  plug Breadcrumb, {"Courses", :course, :index}
  plug Breadcrumb, {:show, :course}
  plug Breadcrumb, {:show, :assignment}
  plug Breadcrumb, {:show, :sub}

  def show(conn, %{"id" => id}) do
    # Re-fetch grade for line comments.
    grade = Grades.get_grade!(id)

    {id, _} = Integer.parse(id)

    assignment = conn.assigns[:assignment]
    show_score = grade.confirmed && !grade_hidden?(conn, assignment)

    grade_json =
      InkfishWeb.Staff.GradeJSON.data(grade)
      |> Map.put(:preview_score, nil)

    data =
      Inkfish.Subs.read_sub_data(grade.sub_id)
      |> Map.put(:edit, false)
      |> Map.put(:grade_id, id)
      |> Map.put(:grade, grade_json)

    render(conn, "show.html",
      fluid_grid: true,
      grade: grade,
      data: data,
      show_score: show_score
    )
  end
end
