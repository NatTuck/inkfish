defmodule InkfishWeb.Staff.GradeControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  alias Inkfish.Uploads.Upload

  setup %{conn: conn} do
    %{staff: staff, sub: sub, grade: grade} = stock_course()
    conn = login(conn, staff)
    {:ok, conn: conn, staff: staff, sub: sub, grade: grade}
  end

  describe "show grade" do
    test "shows grade", %{conn: conn, grade: grade} do
      conn = get(conn, ~p"/staff/grades/#{grade}")
      assert html_response(conn, 200) =~ "Show Grade"
    end

    test "javascript data is properly escaped", %{conn: conn, grade: grade} do
      upload = grade.sub.upload
      unpacked = Upload.unpacked_path(upload)
      File.mkdir_p!(unpacked)

      File.write!(Path.join(unpacked, "test.js"), "var x = \"hello\";")
      File.write!(Path.join(unpacked, "draw.js/"), "content with \"quotes\"")

      File.write!(
        Path.join(unpacked, "file\nwith\nnewlines.txt"),
        "line1\nline2"
      )

      conn = get(conn, ~p"/staff/grades/#{grade}")
      html = html_response(conn, 200)

      refute html =~ "window.code_view_data",
             "Show page should not have code viewer for this grade type"
    end
  end

  describe "create grade" do
    test "redirects to show when data is valid", %{conn: conn, sub: sub} do
      params = params_with_assocs(:grade)

      conn =
        post(conn, ~p"/staff/subs/#{sub}/grades", grade: params)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/staff/grades/#{id}/edit"

      conn = get(conn, ~p"/staff/grades/#{id}")
      assert html_response(conn, 200) =~ "Show Grade"
    end

    test "fails when data is invalid", %{conn: conn, sub: sub} do
      params = %{grade_column_id: nil}

      conn =
        post(conn, ~p"/staff/subs/#{sub}/grades", grade: params)

      assert Phoenix.Flash.get(conn.assigns[:flash], :error) =~
               "Failed to create grade"
    end
  end

  describe "edit grade page" do
    test "renders form for editing chosen grade", %{conn: conn, grade: grade} do
      conn = get(conn, ~p"/staff/grades/#{grade}/edit")
      assert html_response(conn, 200) =~ "Edit Grade"
    end

    test "shows Draft badge when unconfirmed", %{conn: conn, grade: grade} do
      # Ensure grade is unconfirmed feedback grade
      grade = Inkfish.Grades.get_grade!(grade.id)

      conn = get(conn, ~p"/staff/grades/#{grade}/edit")
      html = html_response(conn, 200)

      assert html =~ "Draft"
    end

    test "shows Confirmed badge when confirmed", %{conn: conn, grade: grade} do
      # Confirm the grade
      {:ok, confirmed_grade} = Inkfish.Grades.confirm_grade(grade.id)

      conn = get(conn, ~p"/staff/grades/#{confirmed_grade}/edit")
      html = html_response(conn, 200)

      assert html =~ "Confirmed"
    end

    test "shows unlock button when confirmed", %{conn: conn, grade: grade} do
      # Confirm the grade
      {:ok, confirmed_grade} = Inkfish.Grades.confirm_grade(grade.id)

      conn = get(conn, ~p"/staff/grades/#{confirmed_grade}/edit")
      html = html_response(conn, 200)

      assert html =~ "Unlock"
    end

    test "javascript data is properly escaped for edit", %{
      conn: conn,
      grade: grade
    } do
      upload = grade.sub.upload
      unpacked = Upload.unpacked_path(upload)
      File.mkdir_p!(unpacked)

      File.write!(Path.join(unpacked, "test.js"), "var x = \"hello\";")

      File.write!(
        Path.join(unpacked, "problematic.txt"),
        "Content with \"quotes\" and\nnewlines"
      )

      conn = get(conn, ~p"/staff/grades/#{grade}/edit")
      html = html_response(conn, 200)

      assert html =~ "window.code_view_data = JSON.parse(",
             "Should use JSON.parse for proper escaping"

      assert html =~ "test.js",
             "Should contain file name test.js"

      assert html =~ "problematic.txt",
             "Should contain file name"

      refute html =~ ~s("test.js"),
             "Should not have unescaped quotes in file names"
    end
  end

  describe "grade json data with confirmation" do
    test "includes confirmed field", %{grade: grade} do
      json_data = InkfishWeb.Staff.GradeJSON.data(grade)
      assert json_data.confirmed == false
    end

    test "includes preview_score when unconfirmed", %{grade: grade} do
      # Add a line comment to the grade
      insert(:line_comment,
        grade: grade,
        points: Decimal.new("-5.0"),
        path: "Ω_grading_extra.txt",
        line: 3
      )

      # Reload grade with comments
      grade = Inkfish.Grades.get_grade!(grade.id)
      json_data = InkfishWeb.Staff.GradeJSON.data(grade)

      assert json_data.confirmed == false
      assert json_data.score == nil
      assert json_data.preview_score == Decimal.new("35.0")
    end

    test "preview_score is nil when confirmed", %{grade: grade} do
      # Add comment and confirm the grade first
      insert(:line_comment,
        grade: grade,
        points: Decimal.new("-5.0"),
        path: "Ω_grading_extra.txt",
        line: 3
      )

      {:ok, confirmed_grade} = Inkfish.Grades.confirm_grade(grade.id)
      json_data = InkfishWeb.Staff.GradeJSON.data(confirmed_grade)

      assert json_data.confirmed == true
      assert json_data.preview_score == nil
      assert json_data.score == Decimal.new("35.0")
    end

    test "line comments sorted by path then line", %{grade: grade} do
      # Create comments in random order
      insert(:line_comment,
        grade: grade,
        path: "b_file.c",
        line: 10
      )

      insert(:line_comment,
        grade: grade,
        path: "a_file.c",
        line: 20
      )

      insert(:line_comment,
        grade: grade,
        path: "a_file.c",
        line: 5
      )

      # Reload grade with comments
      grade = Inkfish.Grades.get_grade!(grade.id)
      json_data = InkfishWeb.Staff.GradeJSON.data(grade)

      comments = json_data.line_comments

      # Should be sorted: a_file.c:5, a_file.c:20, b_file.c:10
      assert Enum.at(comments, 0).path == "a_file.c"
      assert Enum.at(comments, 0).line == 5

      assert Enum.at(comments, 1).path == "a_file.c"
      assert Enum.at(comments, 1).line == 20

      assert Enum.at(comments, 2).path == "b_file.c"
      assert Enum.at(comments, 2).line == 10
    end
  end

  describe "confirm review page" do
    test "shows confirmation review page", %{conn: conn, grade: grade} do
      # Add some line comments
      insert(:line_comment,
        grade: grade,
        path: "Ω_grading_extra.txt",
        line: 3,
        points: Decimal.new("-5.0"),
        text: "Style issue"
      )

      conn = get(conn, ~p"/staff/grades/#{grade}/confirm-review")
      html = html_response(conn, 200)

      assert html =~ "Review and Confirm"
      assert html =~ "Style issue"
      assert html =~ "Confirm Comments and Deductions"
    end

    test "shows line context for each comment", %{conn: conn, grade: grade} do
      upload = grade.sub.upload
      unpacked = Inkfish.Uploads.Upload.unpacked_path(upload)
      File.mkdir_p!(unpacked)

      File.write!(Path.join(unpacked, "test.txt"), """
      Line 1
      Line 2
      Line 3: commented line
      Line 4
      Line 5
      Line 6
      """)

      insert(:line_comment,
        grade: grade,
        path: "test.txt",
        line: 3,
        text: "Test comment"
      )

      conn = get(conn, ~p"/staff/grades/#{grade}/confirm-review")
      html = html_response(conn, 200)

      # Should show context lines (line 1-5 for comment on line 3)
      assert html =~ "Line 1"
      assert html =~ "Line 2"
      assert html =~ "Line 3"
      assert html =~ "Line 4"
      assert html =~ "Line 5"
    end

    test "shows comment usage statistics", %{conn: conn, grade: grade} do
      # Create another submission with same comment
      asgn = grade.grade_column.assignment
      sub2 = insert(:sub, assignment: asgn)

      grade2 =
        insert(:grade,
          grade_column: grade.grade_column,
          sub: sub2,
          confirmed: false
        )

      insert(:line_comment,
        grade: grade,
        path: "Ω_grading_extra.txt",
        line: 3,
        text: "Same comment text"
      )

      insert(:line_comment,
        grade: grade2,
        path: "Ω_grading_extra.txt",
        line: 3,
        text: "Same comment text"
      )

      conn = get(conn, ~p"/staff/grades/#{grade}/confirm-review")
      html = html_response(conn, 200)

      # Should show usage count
      assert html =~ "Used on"
      assert html =~ "other submission"
    end

    test "shows points for each comment", %{conn: conn, grade: grade} do
      insert(:line_comment,
        grade: grade,
        path: "Ω_grading_extra.txt",
        line: 3,
        points: Decimal.new("-5.0"),
        text: "Deduct points"
      )

      conn = get(conn, ~p"/staff/grades/#{grade}/confirm-review")
      html = html_response(conn, 200)

      assert html =~ "-5.0"
    end

    test "shows total deduction preview", %{conn: conn, grade: grade} do
      insert(:line_comment,
        grade: grade,
        path: "Ω_grading_extra.txt",
        line: 3,
        points: Decimal.new("-5.0"),
        text: "First deduction"
      )

      insert(:line_comment,
        grade: grade,
        path: "Ω_grading_extra.txt",
        line: 5,
        points: Decimal.new("-3.0"),
        text: "Second deduction"
      )

      conn = get(conn, ~p"/staff/grades/#{grade}/confirm-review")
      html = html_response(conn, 200)

      # Should show preview score (40 - 8 = 32)
      assert html =~ "32"
    end
  end
end
