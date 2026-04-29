defmodule InkfishWeb.Staff.DashboardControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.Factory

  setup %{conn: conn} do
    staff = insert(:user)
    course = insert(:course)
    _staff_reg = insert(:reg, course: course, user: staff, is_staff: true)
    conn = login(conn, staff)
    {:ok, conn: conn, course: course, staff: staff}
  end

  describe "index" do
    test "renders dashboard for staff user", %{conn: conn, course: course} do
      bucket = insert(:bucket, course: course, name: "Homework")
      teamset = insert(:teamset, course: course)

      past_asg =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          name: "Past HW",
          due: Inkfish.LocalTime.in_days(-5)
        )

      insert(:grade_column,
        assignment: past_asg,
        kind: "feedback",
        name: "Feedback",
        points: "10",
        base: "0"
      )

      conn = get(conn, ~p"/staff/dashboard")
      assert html_response(conn, 200) =~ "Staff Dashboard"
      assert html_response(conn, 200) =~ course.name
    end

    test "shows past assignments with ungraded submissions", %{
      conn: conn,
      course: course
    } do
      bucket = insert(:bucket, course: course, name: "Homework")
      teamset = insert(:teamset, course: course)

      past_asg =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          name: "Past HW",
          due: Inkfish.LocalTime.in_days(-5)
        )

      insert(:grade_column,
        assignment: past_asg,
        kind: "feedback",
        name: "Feedback",
        points: "10",
        base: "0"
      )

      student = insert(:user)

      student_reg =
        insert(:reg, user: student, course: course, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)
      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: past_asg,
          reg: student_reg,
          team: team,
          upload: upload,
          active: true
        )

      insert(:active_sub,
        reg: student_reg,
        assignment: past_asg,
        sub: sub
      )

      conn = get(conn, ~p"/staff/dashboard")
      assert html_response(conn, 200) =~ "Past HW"
      assert html_response(conn, 200) =~ "1"
    end

    test "shows upcoming assignments grouped by bucket", %{
      conn: conn,
      course: course
    } do
      bucket1 = insert(:bucket, course: course, name: "Homework")
      bucket2 = insert(:bucket, course: course, name: "Projects")
      teamset = insert(:teamset, course: course)

      insert(:assignment,
        bucket: bucket1,
        teamset: teamset,
        name: "HW 1",
        due: Inkfish.LocalTime.in_days(3)
      )

      insert(:assignment,
        bucket: bucket2,
        teamset: teamset,
        name: "Project 1",
        due: Inkfish.LocalTime.in_days(20)
      )

      conn = get(conn, ~p"/staff/dashboard")
      assert html_response(conn, 200) =~ "Homework"
      assert html_response(conn, 200) =~ "Projects"
      assert html_response(conn, 200) =~ "HW 1"
      assert html_response(conn, 200) =~ "Project 1"
    end

    test "shows empty state when no staff regs", %{conn: _conn} do
      user = insert(:user)
      conn = login(build_conn(), user)

      conn = get(conn, ~p"/staff/dashboard")
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Access denied."
    end

    test "prof user can see dashboard", %{conn: _conn} do
      prof = insert(:user)
      course = insert(:course)
      _prof_reg = insert(:reg, course: course, user: prof, is_prof: true)
      conn = login(build_conn(), prof)

      conn = get(conn, ~p"/staff/dashboard")
      assert html_response(conn, 200) =~ "Staff Dashboard"
    end

    test "admin can see dashboard even without staff regs", %{conn: _conn} do
      admin = insert(:user, is_admin: true)
      conn = login(build_conn(), admin)

      conn = get(conn, ~p"/staff/dashboard")
      assert html_response(conn, 200) =~ "Staff Dashboard"
    end

    test "does not show archived courses", %{conn: _conn} do
      staff = insert(:user)
      active_course = insert(:course, archived: false, name: "Active Course")
      archived_course = insert(:course, archived: true, name: "Archived Course")
      insert(:reg, course: active_course, user: staff, is_staff: true)
      insert(:reg, course: archived_course, user: staff, is_staff: true)
      conn = login(build_conn(), staff)

      conn = get(conn, ~p"/staff/dashboard")
      assert html_response(conn, 200) =~ "Active Course"
      refute html_response(conn, 200) =~ "Archived Course"
    end

    test "does not show past assignments with zero submissions", %{
      conn: conn,
      course: course
    } do
      bucket = insert(:bucket, course: course, name: "Homework")
      teamset = insert(:teamset, course: course)

      past_asg =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          name: "Past HW No Subs",
          due: Inkfish.LocalTime.in_days(-5)
        )

      insert(:grade_column,
        assignment: past_asg,
        kind: "feedback",
        name: "Feedback",
        points: "10",
        base: "0"
      )

      conn = get(conn, ~p"/staff/dashboard")
      refute html_response(conn, 200) =~ "Past HW No Subs"
    end

    test "shows overdue status for old ungraded assignments", %{
      conn: conn,
      course: course
    } do
      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)

      past_asg =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          name: "Overdue HW",
          due: Inkfish.LocalTime.in_days(-10)
        )

      insert(:grade_column,
        assignment: past_asg,
        kind: "feedback",
        name: "Feedback",
        points: "10",
        base: "0"
      )

      student = insert(:user)

      student_reg =
        insert(:reg, user: student, course: course, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)
      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: past_asg,
          reg: student_reg,
          team: team,
          upload: upload,
          active: true
        )

      insert(:active_sub,
        reg: student_reg,
        assignment: past_asg,
        sub: sub
      )

      conn = get(conn, ~p"/staff/dashboard")
      assert html_response(conn, 200) =~ "Overdue HW"
      assert html_response(conn, 200) =~ "overdue"
    end

    test "non-staff user cannot access dashboard", %{conn: _conn} do
      student = insert(:user)
      course = insert(:course)
      insert(:reg, course: course, user: student, is_student: true)
      conn = login(build_conn(), student)

      conn = get(conn, ~p"/staff/dashboard")
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Access denied."
    end
  end
end
