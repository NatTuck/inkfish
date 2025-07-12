defmodule InkfishWeb.Staff.GradeColumnControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    %{staff: staff, assignment: assignment, grade_column: grade_column} =
      stock_course()

    conn = login(conn, staff)

    {:ok,
     conn: conn,
     staff: staff,
     assignment: assignment,
     grade_column: grade_column}
  end

  describe "index" do
    test "lists all grade_columns", %{conn: conn, assignment: asg} do
      conn =
        get(conn, ~p"/staff/assignments/#{asg}/grade_columns")

      assert html_response(conn, 200) =~ "Listing Grade_Columns"
    end
  end

  describe "new grade_column" do
    test "renders form", %{conn: conn, assignment: asg} do
      conn =
        get(conn, ~p"/staff/assignments/#{asg}/grade_columns/new")

      assert html_response(conn, 200) =~ "New Grade Column"
    end
  end

  describe "create grade_column" do
    test "redirects to show when data is valid", %{conn: conn, assignment: asg} do
      params = params_for(:grade_column)

      conn =
        post(
          conn,
          ~p"/staff/assignments/#{asg}/grade_columns",
          grade_column: params
        )

      assert %{id: id} = redirected_params(conn)

      assert redirected_to(conn) ==
               ~p"/staff/grade_columns/#{id}"

      conn = get(conn, ~p"/staff/grade_columns/#{id}")
      assert html_response(conn, 200) =~ "Show Grade Column"
    end

    test "renders errors when data is invalid", %{conn: conn, assignment: asg} do
      params = %{name: ""}

      conn =
        post(
          conn,
          ~p"/staff/assignments/#{asg}/grade_columns",
          grade_column: params
        )

      assert html_response(conn, 200) =~ "New Grade Column"
    end
  end

  describe "edit grade_column" do
    test "renders form for editing chosen grade_column", %{
      conn: conn,
      grade_column: gc
    } do
      conn = get(conn, ~p"/staff/grade_columns/#{gc}/edit")
      assert html_response(conn, 200) =~ "Edit Grade Column"
    end
  end

  describe "update grade_column" do
    test "redirects when data is valid", %{conn: conn, grade_column: gc} do
      params = %{name: "some updated name"}

      conn =
        put(conn, ~p"/staff/grade_columns/#{gc}",
          grade_column: params
        )

      assert redirected_to(conn) ==
               ~p"/staff/grade_columns/#{gc}"

      conn = get(conn, ~p"/staff/grade_columns/#{gc}")
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders errors when data is invalid", %{conn: conn, grade_column: gc} do
      params = %{name: ""}

      conn =
        put(conn, ~p"/staff/grade_columns/#{gc}",
          grade_column: params
        )

      assert html_response(conn, 200) =~ "Edit Grade Column"
    end
  end

  describe "delete grade_column" do
    test "deletes chosen grade_column", %{
      conn: conn,
      grade_column: grade_column
    } do
      conn =
        delete(
          conn,
          ~p"/staff/grade_columns/#{grade_column}"
        )

      assert redirected_to(conn) ==
               ~p"/staff/assignments/#{grade_column.assignment_id}"

      assert_error_sent 404, fn ->
        get(conn, ~p"/staff/grade_columns/#{grade_column}")
      end
    end
  end
end
