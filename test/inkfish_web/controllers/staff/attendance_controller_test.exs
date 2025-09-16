defmodule InkfishWeb.Staff.AttendanceControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  @update_attrs %{attended_at: ~U[2025-08-03 22:55:00Z]}
  @invalid_attrs %{attended_at: nil}

  describe "index" do
    test "lists all attendances for a meeting", %{conn: conn} do
      # Create course, teamset, meeting and reg for the attendance
      course = insert(:course)
      teamset = insert(:teamset, course: course)
      meeting = insert(:meeting, course: course, teamset: teamset)
      reg = insert(:reg)
      
      # Create an attendance record
      insert(:attendance, meeting: meeting, reg: reg)
      
      # Login as staff with proper permissions
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      _staff_reg = insert(:reg, user: staff, course: course, is_staff: true)
      conn = login(conn, staff)
      
      conn = get(conn, ~p"/staff/meetings/#{meeting.id}/attendances")
      assert html_response(conn, 200) =~ "Attendances"
    end
  end

  describe "edit attendance" do
    setup [:create_attendance_with_context]

    test "renders form for editing chosen attendance", %{conn: conn, attendance: attendance, course: course} do
      # Login as staff with proper permissions
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      _staff_reg = insert(:reg, user: staff, course: course, is_staff: true)
      conn = login(conn, staff)
      
      conn = get(conn, ~p"/staff/attendances/#{attendance.id}/edit")
      assert html_response(conn, 200) =~ "Edit Attendance"
    end
  end

  describe "update attendance" do
    setup [:create_attendance_with_context]

    test "redirects when data is valid", %{conn: conn, attendance: attendance, course: course} do
      # Login as staff with proper permissions
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      _staff_reg = insert(:reg, user: staff, course: course, is_staff: true)
      conn = login(conn, staff)
      
      conn = put(conn, ~p"/staff/attendances/#{attendance.id}", attendance: @update_attrs)
      assert redirected_to(conn) == ~p"/staff/attendances/#{attendance.id}"

      conn = get(conn, ~p"/staff/attendances/#{attendance.id}")
      assert html_response(conn, 200) =~ "Attendance"
    end

    test "renders errors when data is invalid", %{conn: conn, attendance: attendance, course: course} do
      # Login as staff with proper permissions
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      _staff_reg = insert(:reg, user: staff, course: course, is_staff: true)
      conn = login(conn, staff)
      
      conn = put(conn, ~p"/staff/attendances/#{attendance.id}", attendance: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Attendance"
    end
  end

  describe "delete attendance" do
    setup [:create_attendance_with_context]

    test "deletes chosen attendance", %{conn: conn, attendance: attendance, course: course} do
      # Login as staff with proper permissions
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      _staff_reg = insert(:reg, user: staff, course: course, is_staff: true)
      conn = login(conn, staff)
      
      conn = delete(conn, ~p"/staff/attendances/#{attendance.id}")
      assert redirected_to(conn) == ~p"/staff/meetings/#{attendance.meeting_id}"
    end
  end

  describe "excuse attendance" do
    setup [:create_attendance_with_context]

    test "toggles excused status for existing attendance", %{conn: conn, attendance: attendance, course: course, meeting: meeting, reg: reg} do
      # Login as staff with proper permissions
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      _staff_reg = insert(:reg, user: staff, course: course, is_staff: true)
      conn = login(conn, staff)
      
      # First, check that the attendance is not excused
      assert attendance.excused == false
      
      # Toggle the excuse status
      conn = post(conn, ~p"/staff/meetings/#{meeting.id}/excuse/#{reg.id}")
      assert redirected_to(conn) == ~p"/staff/meetings/#{meeting.id}"
      assert get_flash(conn, :info) == "Attendance excuse toggled."
      
      # Verify the attendance is now excused
      updated_attendance = Inkfish.Attendances.get_attendance!(attendance.id)
      assert updated_attendance.excused == true
    end

    test "creates new excused attendance when none exists", %{conn: conn, course: course, meeting: meeting} do
      # Login as staff with proper permissions
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      _staff_reg = insert(:reg, user: staff, course: course, is_staff: true)
      conn = login(conn, staff)
      
      # Create a new reg that doesn't have an attendance yet
      new_reg = insert(:reg)
      
      # Verify no attendance exists for this reg and meeting
      assert Inkfish.Attendances.get_attendance(meeting, new_reg) == nil
      
      # Create an excused attendance
      conn = post(conn, ~p"/staff/meetings/#{meeting.id}/excuse/#{new_reg.id}")
      assert redirected_to(conn) == ~p"/staff/meetings/#{meeting.id}"
      assert get_flash(conn, :info) == "Created excused attendance."
      
      # Verify the excused attendance was created
      new_attendance = Inkfish.Attendances.get_attendance(meeting, new_reg)
      assert new_attendance != nil
      assert new_attendance.excused == true
    end
  end

  defp create_attendance_with_context(_) do
    course = insert(:course)
    teamset = insert(:teamset, course: course)
    meeting = insert(:meeting, course: course, teamset: teamset)
    reg = insert(:reg)
    attendance = insert(:attendance, meeting: meeting, reg: reg)
    %{attendance: attendance, meeting: meeting, reg: reg, course: course}
  end
end
