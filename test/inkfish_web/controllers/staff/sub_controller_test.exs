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

  describe "activate sub" do
    test "activates sub when activate action is called", %{
      conn: conn,
      assignment: assignment
    } do
      # Create a non-active sub for this specific test
      student = Inkfish.Users.get_user_by_email!("dave@example.com")
      course_id = assignment.bucket.course_id

      student_reg =
        Inkfish.Repo.get_by!(Inkfish.Users.Reg,
          course_id: course_id,
          user_id: student.id
        )

      {:ok, team} = Inkfish.Teams.get_active_team(assignment, student_reg)
      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          active: false,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload
        )

      # The sub should start as inactive
      refute sub.active

      # Call the activate action
      conn = post(conn, ~p"/staff/subs/#{sub}/activate")
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check that the sub is now active by looking for the active status text
      conn = get(conn, ~p"/staff/subs/#{sub}")
      # When active, it should show "Active: true" without a form
      assert html_response(conn, 200) =~ "<strong>Active:</strong>\ntrue"
    end
  end

  describe "toggle late penalty" do
    test "toggles late penalty when toggle_late_penalty action is called on inactive sub", %{
      conn: conn,
      assignment: assignment
    } do
      # Create a non-active sub for this specific test
      student = Inkfish.Users.get_user_by_email!("dave@example.com")
      course_id = assignment.bucket.course_id

      student_reg =
        Inkfish.Repo.get_by!(Inkfish.Users.Reg,
          course_id: course_id,
          user_id: student.id
        )

      {:ok, team} = Inkfish.Teams.get_active_team(assignment, student_reg)
      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          active: false,
          assignment: assignment,
          reg: student_reg,
          team: team,
          upload: upload
        )

      # The sub should start as inactive
      refute sub.active

      # Call the toggle_late_penalty action (this should NOT activate the sub)
      conn = post(conn, ~p"/staff/subs/#{sub}/toggle_late_penalty")
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check that the sub is still inactive
      conn = get(conn, ~p"/staff/subs/#{sub}")
      # The sub should still be inactive (no form means it's active)
      assert html_response(conn, 200) =~ "<form action=\"/staff/subs/#{sub.id}\" method=\"post\">"
      assert html_response(conn, 200) =~ "<strong>Active:</strong>\nfalse"
      
      # But the late penalty should be toggled
      assert html_response(conn, 200) =~ "<strong>Ignore Late Penalty:</strong>\ntrue"
    end

    test "toggles late penalty when toggle_late_penalty action is called on active sub", %{
      conn: conn,
      sub: sub
    } do
      # The sub should start as active (from factory) and ignore_late_penalty as false
      assert sub.active
      refute sub.ignore_late_penalty

      # Call the toggle_late_penalty action
      conn = post(conn, ~p"/staff/subs/#{sub}/toggle_late_penalty")
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check that the sub is still active
      conn = get(conn, ~p"/staff/subs/#{sub}")
      # When active, there should be no activate form
      refute html_response(conn, 200) =~ "<input id=\"sub_active\" name=\"sub[active]\" type=\"hidden\" value=\"true\">"
      # But we should see the active status
      assert html_response(conn, 200) =~ "<strong>Active:</strong>\ntrue"
      
      # But the late penalty should be toggled
      assert html_response(conn, 200) =~ "<strong>Ignore Late Penalty:</strong>\ntrue"

      # Call the toggle_late_penalty action again
      conn = post(conn, ~p"/staff/subs/#{sub}/toggle_late_penalty")
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check that the sub is still active
      conn = get(conn, ~p"/staff/subs/#{sub}")
      # When active, there should be no activate form
      refute html_response(conn, 200) =~ "<input id=\"sub_active\" name=\"sub[active]\" type=\"hidden\" value=\"true\">"
      # But we should see the active status
      assert html_response(conn, 200) =~ "<strong>Active:</strong>\ntrue"
      
      # And the late penalty should be toggled back
      assert html_response(conn, 200) =~ "<strong>Ignore Late Penalty:</strong>\nfalse"
    end
  end

  describe "update sub" do
    test "updates grader when grader_id is provided", %{
      conn: conn,
      sub: sub,
      staff: staff
    } do
      # Test setting grader ID
      params = %{"grader_id" => "#{staff.id}"}
      conn = put(conn, ~p"/staff/subs/#{sub}", sub: params)
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check that the grader was set
      conn = get(conn, ~p"/staff/subs/#{sub}")
      assert html_response(conn, 200) =~ "Updated sub flags: ##{sub.id}"
    end
  end
end
