defmodule InkfishWeb.SubControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    %{student: student, assignment: assignment, grade: grade} = stock_course()
    conn = login(conn, student)
    {:ok, conn: conn, grade: grade, assignment: assignment}
  end

  describe "new sub" do
    test "renders form", %{conn: conn, assignment: asg} do
      conn = get(conn, ~p"/assignments/#{asg}/subs/new")
      assert html_response(conn, 200) =~ "New Sub"
    end
  end

  describe "create sub" do
    test "redirects to show when data is valid", %{conn: conn, assignment: asg} do
      params = params_with_assocs(:sub, assignment: asg)

      conn =
        post(conn, ~p"/assignments/#{asg}/subs", sub: params)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/subs/#{id}"

      conn = get(conn, ~p"/subs/#{id}")
      assert html_response(conn, 200) =~ "Show Sub"
    end

    test "renders errors when data is invalid", %{conn: conn, assignment: asg} do
      params = %{}

      conn =
        post(conn, ~p"/assignments/#{asg}/subs", sub: params)

      assert html_response(conn, 200) =~ "New Sub"
    end
  end

  describe "show sub with feedback grade" do
    test "grade link visible even before grades released", %{conn: conn} do
      due = Inkfish.LocalTime.in_days(1)
      course = insert(:course)
      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)

      asgn =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          due: due,
          force_show_grades: false
        )

      feedback_gcol =
        insert(:grade_column,
          kind: "feedback",
          assignment: asgn,
          name: "Code Review"
        )

      student = insert(:user)

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)

      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: asgn,
          reg: student_reg,
          team: team,
          upload: upload
        )

      grade =
        insert(:grade,
          grade_column: feedback_gcol,
          sub: sub,
          confirmed: true,
          score: Decimal.new("8.0")
        )

      insert(:line_comment,
        grade: grade,
        path: "main.c",
        line: 5,
        text: "Good work here"
      )

      conn = login(conn, student)
      conn = get(conn, ~p"/subs/#{sub}")

      html = html_response(conn, 200)

      assert html =~ "Code Review"
      assert html =~ ~p"/grades/#{grade}"
    end
  end
end
