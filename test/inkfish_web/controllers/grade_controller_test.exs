defmodule InkfishWeb.GradeControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  defp create_grade(_) do
    due = Inkfish.LocalTime.in_days(-7)
    asgn = insert(:assignment, due: due)
    sub = insert(:sub, assignment: asgn)
    grade = insert(:grade, sub: sub)
    {:ok, grade: grade}
  end

  defp create_feedback_grade(_) do
    due = Inkfish.LocalTime.in_days(-7)
    asgn = insert(:assignment, due: due)
    sub = insert(:sub, assignment: asgn)
    gcol = insert(:grade_column, kind: "feedback", assignment: asgn)
    grade = insert(:grade, sub: sub, grade_column: gcol, confirmed: false)
    {:ok, grade: grade, asgn: asgn, sub: sub}
  end

  describe "show grade" do
    setup [:create_grade]

    test "show chosen grade", %{conn: conn, grade: grade} do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/grades/#{grade}")

      assert html_response(conn, 200) =~ "Show Grade"
    end
  end

  describe "show feedback grade" do
    setup [:create_feedback_grade]

    test "shows Draft badge when unconfirmed", %{conn: conn, grade: grade} do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/grades/#{grade}")

      html = html_response(conn, 200)
      assert html =~ "Draft"
    end

    test "hides numeric score when unconfirmed", %{conn: conn, grade: grade} do
      insert(:line_comment,
        grade: grade,
        points: Decimal.new("-5.0"),
        path: "Ω_grading_extra.txt",
        line: 3
      )

      grade = Inkfish.Grades.get_grade!(grade.id)

      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/grades/#{grade}")

      html = html_response(conn, 200)
      refute html =~ "35.0"
      assert html =~ "--"
    end

    test "shows score when confirmed and grades released", %{
      conn: conn,
      grade: grade
    } do
      insert(:line_comment,
        grade: grade,
        points: Decimal.new("-5.0"),
        path: "Ω_grading_extra.txt",
        line: 3
      )

      {:ok, confirmed_grade} = Inkfish.Grades.confirm_grade(grade.id)

      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/grades/#{confirmed_grade}")

      html = html_response(conn, 200)
      assert html =~ "35.0"
    end

    test "shows code viewer and comments even before grades released", %{
      conn: conn
    } do
      due = Inkfish.LocalTime.in_days(1)
      asgn = insert(:assignment, due: due, force_show_grades: false)
      sub = insert(:sub, assignment: asgn)
      gcol = insert(:grade_column, kind: "feedback", assignment: asgn)

      grade =
        insert(:grade,
          sub: sub,
          grade_column: gcol,
          score: Decimal.new("8.0"),
          confirmed: true
        )

      insert(:line_comment,
        grade: grade,
        points: Decimal.new("-2.0"),
        path: "main.c",
        line: 10,
        text: "Comment visible before release"
      )

      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/grades/#{grade}")

      html = html_response(conn, 200)
      assert html =~ "Confirmed"
      assert html =~ "Score available after grades are released"
      assert html =~ "code-viewer"
    end

    test "shows score when confirmed and force_show_grades enabled", %{
      conn: conn
    } do
      due = Inkfish.LocalTime.in_days(1)
      asgn = insert(:assignment, due: due, force_show_grades: true)
      sub = insert(:sub, assignment: asgn)
      gcol = insert(:grade_column, kind: "feedback", assignment: asgn)

      grade =
        insert(:grade,
          sub: sub,
          grade_column: gcol,
          score: Decimal.new("8.0"),
          confirmed: true
        )

      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/grades/#{grade}")

      html = html_response(conn, 200)
      assert html =~ "Confirmed"
      assert html =~ "8.0"
    end
  end
end
