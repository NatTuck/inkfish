defmodule InkfishWeb.Staff.AttendanceControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  @create_attrs %{attended_at: ~U[2025-08-02 22:55:00Z]}
  @update_attrs %{attended_at: ~U[2025-08-03 22:55:00Z]}
  @invalid_attrs %{attended_at: nil}

  describe "index" do
    test "lists all attendances", %{conn: conn} do
      # Create a meeting and reg for the attendance
      meeting = insert(:meeting)
      reg = insert(:reg)
      
      # Create an attendance record
      insert(:attendance, meeting: meeting, reg: reg)
      
      # Login as staff
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      conn = login(conn, staff)
      
      conn = get(conn, ~p"/staff/attendances")
      assert html_response(conn, 200) =~ "Attendances"
    end
  end

  describe "edit attendance" do
    setup [:create_attendance_with_context]

    test "renders form for editing chosen attendance", %{conn: conn, attendance: attendance} do
      # Login as staff
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      conn = login(conn, staff)
      
      conn = get(conn, ~p"/staff/attendances/#{attendance.id}/edit")
      assert html_response(conn, 200) =~ "Edit Attendance"
    end
  end

  describe "update attendance" do
    setup [:create_attendance_with_context]

    test "redirects when data is valid", %{conn: conn, attendance: attendance} do
      # Login as staff
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      conn = login(conn, staff)
      
      conn = put(conn, ~p"/staff/attendances/#{attendance.id}", attendance: @update_attrs)
      assert redirected_to(conn) == ~p"/staff/attendances/#{attendance.id}"

      conn = get(conn, ~p"/staff/attendances/#{attendance.id}")
      assert html_response(conn, 200) =~ "Attendance"
    end

    test "renders errors when data is invalid", %{conn: conn, attendance: attendance} do
      # Login as staff
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      conn = login(conn, staff)
      
      conn = put(conn, ~p"/staff/attendances/#{attendance.id}", attendance: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Attendance"
    end
  end

  describe "delete attendance" do
    setup [:create_attendance_with_context]

    test "deletes chosen attendance", %{conn: conn, attendance: attendance} do
      # Login as staff
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      conn = login(conn, staff)
      
      conn = delete(conn, ~p"/staff/attendances/#{attendance.id}")
      assert redirected_to(conn) == ~p"/staff/meetings/#{attendance.meeting_id}"

      assert_error_sent 404, fn ->
        get(conn, ~p"/staff/attendances/#{attendance.id}")
      end
    end
  end

  defp create_attendance_with_context(_) do
    course = insert(:course)
    teamset = insert(:teamset, course: course)
    meeting = insert(:meeting, course: course, teamset: teamset)
    reg = insert(:reg)
    attendance = insert(:attendance, meeting: meeting, reg: reg)
    %{attendance: attendance, meeting: meeting, reg: reg}
  end
end
