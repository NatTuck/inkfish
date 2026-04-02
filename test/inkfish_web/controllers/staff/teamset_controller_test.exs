defmodule InkfishWeb.Staff.TeamsetControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    course = insert(:course)
    staff = insert(:user)

    _sr =
      insert(:reg,
        course: course,
        user: staff,
        is_staff: true,
        is_student: false
      )

    teamset = insert(:teamset, course: course)
    conn = login(conn, staff.email)
    {:ok, conn: conn, course: course, teamset: teamset, staff: staff}
  end

  describe "index" do
    test "lists all teamsets", %{conn: conn, course: course} do
      conn = get(conn, ~p"/staff/courses/#{course}/teamsets")
      assert html_response(conn, 200) =~ "Listing Teamsets"
    end
  end

  describe "new teamset" do
    test "renders form", %{conn: conn, course: course} do
      conn = get(conn, ~p"/staff/courses/#{course}/teamsets/new")
      assert html_response(conn, 200) =~ "New Teamset"
    end
  end

  describe "create teamset" do
    test "redirects to show when data is valid", %{conn: conn, course: course} do
      params = params_for(:teamset, course: course)

      conn =
        post(conn, ~p"/staff/courses/#{course}/teamsets", teamset: params)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/staff/teamsets/#{id}"

      conn = get(conn, ~p"/staff/teamsets/#{id}")
      assert html_response(conn, 200) =~ "Show Teamset"
    end

    test "renders errors when data is invalid", %{conn: conn, course: course} do
      params = %{name: ""}

      conn =
        post(conn, ~p"/staff/courses/#{course}/teamsets", teamset: params)

      assert html_response(conn, 200) =~ "New Teamset"
    end
  end

  describe "edit teamset" do
    test "renders form for editing chosen teamset", %{
      conn: conn,
      teamset: teamset
    } do
      conn = get(conn, ~p"/staff/teamsets/#{teamset}/edit")
      assert html_response(conn, 200) =~ "Edit Teamset"
    end
  end

  describe "update teamset" do
    test "redirects when data is valid", %{conn: conn, teamset: teamset} do
      params = %{name: "new name"}

      conn =
        put(conn, ~p"/staff/teamsets/#{teamset}", teamset: params)

      assert redirected_to(conn) ==
               ~p"/staff/teamsets/#{teamset}"

      conn = get(conn, ~p"/staff/teamsets/#{teamset}")
      assert html_response(conn, 200) =~ "new name"
    end

    test "renders errors when data is invalid", %{conn: conn, teamset: teamset} do
      params = %{name: ""}

      conn =
        put(conn, ~p"/staff/teamsets/#{teamset}", teamset: params)

      assert html_response(conn, 200) =~ "Edit Teamset"
    end
  end

  describe "delete teamset" do
    test "deletes chosen teamset", %{conn: conn, teamset: teamset} do
      conn = delete(conn, ~p"/staff/teamsets/#{teamset}")

      assert redirected_to(conn) ==
               ~p"/staff/courses/#{teamset.course_id}/teamsets"

      conn = get(conn, ~p"/staff/teamsets/#{teamset}")
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "show teamset with attendance" do
    test "show includes meeting when current meeting exists", %{
      conn: conn,
      course: course
    } do
      teamset = insert(:teamset, course: course)
      _meeting = insert(:meeting, course: course, teamset: teamset)

      conn = get(conn, ~p"/staff/teamsets/#{teamset}")

      html = html_response(conn, 200)
      assert html =~ "Teamset:"
      assert html =~ "window.meeting"
      assert html =~ "window.attendances"
    end

    test "show includes student with existing attendance in attendances list",
         %{conn: conn, course: course} do
      teamset = insert(:teamset, course: course)
      meeting = insert(:meeting, course: course, teamset: teamset)

      student = insert(:user, given_name: "Alice", surname: "Student")

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      _attendance = insert(:attendance, meeting: meeting, reg: student_reg)

      conn = get(conn, ~p"/staff/teamsets/#{teamset}")

      html = html_response(conn, 200)

      assert html =~ "Alice Student", "Student name should appear in page"
      assert html =~ "window.attendances"
    end

    test "show includes student without attendance as missing", %{
      conn: conn,
      course: course
    } do
      teamset = insert(:teamset, course: course)
      _meeting = insert(:meeting, course: course, teamset: teamset)

      student = insert(:user, given_name: "Bob", surname: "Absent")

      _student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      conn = get(conn, ~p"/staff/teamsets/#{teamset}")

      html = html_response(conn, 200)

      assert html =~ "Bob Absent", "Student name should appear in page"
    end

    test "show assigns meeting and attendances with correct structure", %{
      conn: conn,
      course: course
    } do
      teamset = insert(:teamset, course: course)
      meeting = insert(:meeting, course: course, teamset: teamset)

      student = insert(:user, given_name: "Test", surname: "User")

      student_reg =
        insert(:reg, course: course, user: student, is_student: true)

      _attendance = insert(:attendance, meeting: meeting, reg: student_reg)

      regs = Inkfish.Users.list_student_regs_for_course(course)
      assert length(regs) == 1, "Should find student reg: #{length(regs)} found"

      conn = get(conn, ~p"/staff/teamsets/#{teamset}")

      assert conn.assigns[:meeting] != nil, "Meeting should be assigned"
      assert conn.assigns[:attendances] != nil, "Attendances should be assigned"
      assert length(conn.assigns[:attendances]) == 1, "Should have one student"

      [reg_json, att_json] = hd(conn.assigns[:attendances])
      assert reg_json.user.name =~ "Test User"

      assert att_json != nil,
             "Attendance should exist for student who checked in"

      assert att_json.status != nil, "Attendance status should be set"
    end
  end
end
