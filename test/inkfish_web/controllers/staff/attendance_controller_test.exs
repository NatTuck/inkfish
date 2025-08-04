defmodule InkfishWeb.Staff.AttendanceControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.AttendancesFixtures

  @create_attrs %{attended_at: ~U[2025-08-02 22:55:00Z]}
  @update_attrs %{attended_at: ~U[2025-08-03 22:55:00Z]}
  @invalid_attrs %{attended_at: nil}

  describe "index" do
    test "lists all attendances", %{conn: conn} do
      conn = get(conn, ~p"/staff/attendances")
      assert html_response(conn, 200) =~ "Listing Attendances"
    end
  end

  describe "new attendance" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/staff/attendances/new")
      assert html_response(conn, 200) =~ "New Attendance"
    end
  end

  describe "create attendance" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/staff/attendances", attendance: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/staff/attendances/#{id}"

      conn = get(conn, ~p"/staff/attendances/#{id}")
      assert html_response(conn, 200) =~ "Attendance #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/staff/attendances", attendance: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Attendance"
    end
  end

  describe "edit attendance" do
    setup [:create_attendance]

    test "renders form for editing chosen attendance", %{conn: conn, attendance: attendance} do
      conn = get(conn, ~p"/staff/attendances/#{attendance}/edit")
      assert html_response(conn, 200) =~ "Edit Attendance"
    end
  end

  describe "update attendance" do
    setup [:create_attendance]

    test "redirects when data is valid", %{conn: conn, attendance: attendance} do
      conn = put(conn, ~p"/staff/attendances/#{attendance}", attendance: @update_attrs)
      assert redirected_to(conn) == ~p"/staff/attendances/#{attendance}"

      conn = get(conn, ~p"/staff/attendances/#{attendance}")
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, attendance: attendance} do
      conn = put(conn, ~p"/staff/attendances/#{attendance}", attendance: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Attendance"
    end
  end

  describe "delete attendance" do
    setup [:create_attendance]

    test "deletes chosen attendance", %{conn: conn, attendance: attendance} do
      conn = delete(conn, ~p"/staff/attendances/#{attendance}")
      assert redirected_to(conn) == ~p"/staff/attendances"

      assert_error_sent 404, fn ->
        get(conn, ~p"/staff/attendances/#{attendance}")
      end
    end
  end

  defp create_attendance(_) do
    attendance = attendance_fixture()
    %{attendance: attendance}
  end
end
