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
      if sub.active do
        # If it's already active, deactivate it first
        sub = Inkfish.Repo.get!(Inkfish.Subs.Sub, sub.id)
        {:ok, _sub} = Inkfish.Subs.update_sub(sub, %{active: false})
      end
      
      # Reload the sub to get the current state
      sub = Inkfish.Repo.get!(Inkfish.Subs.Sub, sub.id)
      refute sub.active
      
      # Press the activate button
      params = %{active: true}
      conn = put(conn, ~p"/staff/subs/#{sub}", sub: params)
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"
      
      # Check that the sub is now active by looking for the active status text
      conn = get(conn, ~p"/staff/subs/#{sub}")
      # When active, it should show "Active: true" without a form
      assert html_response(conn, 200) =~ "<strong>Active:</strong>\ntrue"
    end

    test "toggles late penalty when toggle button is pressed", %{conn: conn, sub: sub} do
      # First ensure the late penalty setting is false
      if sub.ignore_late_penalty do
        # If it's already true, set it to false first
        sub = Inkfish.Repo.get!(Inkfish.Subs.Sub, sub.id)
        {:ok, _sub} = Inkfish.Subs.update_sub(sub, %{ignore_late_penalty: false})
      end
      
      # Reload the sub to get the current state
      sub = Inkfish.Repo.get!(Inkfish.Subs.Sub, sub.id)
      refute sub.ignore_late_penalty
      
      # Press the toggle button
      params = %{ignore_late_penalty: true}
      conn = put(conn, ~p"/staff/subs/#{sub}", sub: params)
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"
      
      # Check that the late penalty setting is now true
      conn = get(conn, ~p"/staff/subs/#{sub}")
      # Look for the text that shows the current value is true
      assert html_response(conn, 200) =~ "<strong>Ignore Late Penalty:</strong>\ntrue"
      
      # Press the toggle button again
      params = %{ignore_late_penalty: false}
      conn = put(conn, ~p"/staff/subs/#{sub}", sub: params)
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"
      
      # Check that the late penalty setting is now false
      conn = get(conn, ~p"/staff/subs/#{sub}")
      # Look for the text that shows the current value is false
      assert html_response(conn, 200) =~ "<strong>Ignore Late Penalty:</strong>\nfalse"
    end
  end
end
