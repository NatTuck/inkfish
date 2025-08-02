defmodule InkfishWeb.Staff.GradeControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

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
  end

  describe "create grade" do
    test "redirects to show when data is valid", %{conn: conn, sub: sub} do
      params = params_with_assocs(:grade)

      conn =
        post(conn, ~p"/staff/subs/#{sub}/grades",
          grade: params
        )

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/staff/grades/#{id}/edit"

      conn = get(conn, ~p"/staff/grades/#{id}")
      assert html_response(conn, 200) =~ "Show Grade"
    end

    test "fails when data is invalid", %{conn: conn, sub: sub} do
      params = %{grade_column_id: nil}

      conn =
        post(conn, ~p"/staff/subs/#{sub}/grades",
          grade: params
        )

      assert Phoenix.Flash.get(conn.assigns[:flash], :error) =~
               "Failed to create grade"
    end
  end

  describe "edit grade" do
    test "renders form for editing chosen grade", %{conn: conn, grade: grade} do
      conn = get(conn, ~p"/staff/grades/#{grade}/edit")
      assert html_response(conn, 200) =~ "Edit Grade"
    end
  end
end
