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
      assert html_response(conn, 200) =~ "Listing Attendances"
    end
  end

  describe "new attendance" do
    test "renders form", %{conn: conn} do
      # Create a meeting for context
      meeting = insert(:meeting)
      
      # Login as staff
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      conn = login(conn, staff)
      
      conn = get(conn, ~p"/staff/meetings/#{meeting.id}/attendances/new")
      assert html_response(conn, 200) =~ "New Attendance"
    end
  end

  describe "create attendance" do
    test "redirects to show when data is valid", %{conn: conn} do
      # Create a meeting and reg for the attendance
      meeting = insert(:meeting)
      reg = insert(:reg)
      
      # Login as staff
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      conn = login(conn, staff)
      
      conn = post(conn, ~p"/staff/meetings/#{meeting.id}/attendances", 
                  attendance: Map.merge(@create_attrs, %{reg_id: reg.id}))

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/staff/attendances/#{id}"

      conn = get(conn, ~p"/staff/attendances/#{id}")
      assert html_response(conn, 200) =~ "Attendance #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      # Create a meeting for context
      meeting = insert(:meeting)
      
      # Login as staff
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      conn = login(conn, staff)
      
      conn = post(conn, ~p"/staff/meetings/#{meeting.id}/attendances", attendance: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Attendance"
    end
  end

  describe "edit attendance" do
    setup [:create_attendance]

    test "renders form for editing chosen attendance", %{conn: conn, attendance: attendance} do
      # Login as staff
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      conn = login(conn, staff)
      
      conn = get(conn, ~p"/staff/attendances/#{attendance.id}/edit")
      assert html_response(conn, 200) =~ "Edit Attendance"
    end
  end

  describe "update attendance" do
    setup [:create_attendance]

    test "redirects when data is valid", %{conn: conn, attendance: attendance} do
      # Login as staff
      staff = Inkfish.Users.get_user_by_email!("carol@example.com")
      conn = login(conn, staff)
      
      conn = put(conn, ~p"/staff/attendances/#{attendance.id}", attendance: @update_attrs)
      assert redirected_to(conn) == ~p"/staff/attendances/#{attendance.id}"

      conn = get(conn, ~p"/staff/attendances/#{attendance.id}")
      assert html_response(conn, 200)
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
    setup [:create_attendance]

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

  defp create_attendance(_) do
    attendance = insert(:attendance)
    %{attendance: attendance}
  end
end
