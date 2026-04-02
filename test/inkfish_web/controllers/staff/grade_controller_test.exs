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

  describe "edit grade" do
    test "renders form for editing chosen grade", %{conn: conn, grade: grade} do
      conn = get(conn, ~p"/staff/grades/#{grade}/edit")
      assert html_response(conn, 200) =~ "Edit Grade"
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
end
