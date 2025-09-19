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
    test "activates sub when activate button is pressed", %{
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

      # Press the activate button
      params = %{"active" => "true"}
      conn = put(conn, ~p"/staff/subs/#{sub}", sub: params)
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check that the sub is now active by looking for the active status text
      conn = get(conn, ~p"/staff/subs/#{sub}")
      # When active, it should show "Active: true" without a form
      assert html_response(conn, 200) =~ "<strong>Active:</strong>\ntrue"
    end

    test "toggles late penalty when toggle button is pressed without changing active state", %{
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

      # Press the toggle late penalty button (this should NOT activate the sub)
      params = %{"ignore_late_penalty" => "true"}
      conn = put(conn, ~p"/staff/subs/#{sub}", sub: params)
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check that the sub is still inactive
      conn = get(conn, ~p"/staff/subs/#{sub}")
      assert html_response(conn, 200) =~ "<strong>Active:</strong>\nfalse"
      
      # But the late penalty should be toggled
      assert html_response(conn, 200) =~ "<strong>Ignore Late Penalty:</strong>\ntrue"
    end

    test "toggles late penalty when toggle button is pressed on active sub", %{
      conn: conn,
      sub: sub
    } do
      # The sub should start as active (from factory) and ignore_late_penalty as false
      assert sub.active
      refute sub.ignore_late_penalty

      # Press the toggle button
      params = %{"ignore_late_penalty" => "true"}
      conn = put(conn, ~p"/staff/subs/#{sub}", sub: params)
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check that the sub is still active
      conn = get(conn, ~p"/staff/subs/#{sub}")
      assert html_response(conn, 200) =~ "<strong>Active:</strong>\ntrue"
      
      # But the late penalty should be toggled
      assert html_response(conn, 200) =~ "<strong>Ignore Late Penalty:</strong>\ntrue"

      # Press the toggle button again
      params = %{"ignore_late_penalty" => "false"}
      conn = put(conn, ~p"/staff/subs/#{sub}", sub: params)
      assert redirected_to(conn) == ~p"/staff/subs/#{sub}"

      # Check that the sub is still active
      conn = get(conn, ~p"/staff/subs/#{sub}")
      assert html_response(conn, 200) =~ "<strong>Active:</strong>\ntrue"
      
      # And the late penalty should be toggled back
      assert html_response(conn, 200) =~ "<strong>Ignore Late Penalty:</strong>\nfalse"
    end
  end
end
