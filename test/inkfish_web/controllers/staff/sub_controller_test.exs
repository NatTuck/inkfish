defmodule InkfishWeb.Staff.SubControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    %{staff: staff, assignment: assignment, sub: sub} = stock_course()
    conn = login(conn, staff)
    {:ok, conn: conn, staff: staff, assignment: assignment, sub: sub}
  end

  describe "show sub" do
    test "shows a sub", %{conn: conn, sub: sub} do
      conn = get(conn, ~p"/staff/subs/#{sub}")
      assert html_response(conn, 200) =~ "Show Sub"
    end
  end

  describe "update sub" do
    test "activates sub when activate button is pressed", %{conn: conn, sub: sub} do
      # First ensure the sub is not active
      refute sub.active
      
      # Press the activate button
      params = %{active: true}
      conn = put(conn, ~p"/staff/subs/#{sub}", sub: params)
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"
      
      # Check that the sub is now active
      conn = get(conn, ~p"/staff/subs/#{sub}")
      assert html_response(conn, 200) =~ "Active:\n      true"
    end

    test "toggles late penalty when toggle button is pressed", %{conn: conn, sub: sub} do
      # First ensure the late penalty setting is false
      refute sub.ignore_late_penalty
      
      # Press the toggle button
      params = %{ignore_late_penalty: true}
      conn = put(conn, ~p"/staff/subs/#{sub}", sub: params)
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"
      
      # Check that the late penalty setting is now true
      conn = get(conn, ~p"/staff/subs/#{sub}")
      assert html_response(conn, 200) =~ "Ignore Late Penalty:\n      true"
      
      # Press the toggle button again
      params = %{ignore_late_penalty: false}
      conn = put(conn, conn, ~p"/staff/subs/#{sub}", sub: params)
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"
      
      # Check that the late penalty setting is now false
      conn = get(conn, ~p"/staff/subs/#{sub}")
      assert html_response(conn, 200) =~ "Ignore Late Penalty:\n      false"
    end
  end
end
