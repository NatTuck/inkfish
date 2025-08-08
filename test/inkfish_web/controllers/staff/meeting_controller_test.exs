defmodule InkfishWeb.Staff.MeetingControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    course = insert(:course)
    staff = insert(:user)
    _sr = insert(:reg, course: course, user: staff, is_staff: true)
    meeting = insert(:meeting, course: course)
    conn = login(conn, staff)
    {:ok, conn: conn, course: course, meeting: meeting, staff: staff}
  end

  describe "index" do
    test "lists all meetings", %{conn: conn, course: course} do
      conn = get(conn, ~p"/staff/courses/#{course}/meetings")
      assert html_response(conn, 200) =~ "Listing Meetings"
    end
  end

  describe "new meeting" do
    test "renders form", %{conn: conn, course: course} do
      conn = get(conn, ~p"/staff/courses/#{course}/meetings/new")
      assert html_response(conn, 200) =~ "New Meeting"
    end
  end

  describe "create meeting" do
    test "redirects to show when data is valid", %{conn: conn, course: course} do
      params = params_for(:meeting)

      conn =
        post(conn, ~p"/staff/courses/#{course}/meetings", meeting: params)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/staff/meetings/#{id}"

      conn = get(conn, ~p"/staff/meetings/#{id}")
      assert html_response(conn, 200) =~ "Show Meeting"
    end

    test "renders errors when data is invalid", %{conn: conn, course: course} do
      params = %{started_at: nil}

      conn =
        post(conn, ~p"/staff/courses/#{course}/meetings", meeting: params)

      assert html_response(conn, 200) =~ "New Meeting"
    end
  end

  describe "edit meeting" do
    test "renders form for editing chosen meeting", %{conn: conn, meeting: meeting} do
      conn = get(conn, ~p"/staff/meetings/#{meeting}/edit")
      assert html_response(conn, 200) =~ "Edit Meeting"
    end
  end

  describe "update meeting" do
    test "redirects when data is valid", %{conn: conn, meeting: meeting} do
      params = %{started_at: Inkfish.LocalTime.in_days(1)}

      conn =
        put(conn, ~p"/staff/meetings/#{meeting}", meeting: params)

      assert redirected_to(conn) == ~p"/staff/meetings/#{meeting}"

      conn = get(conn, ~p"/staff/meetings/#{meeting}")
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, meeting: meeting} do
      params = %{started_at: nil}

      conn =
        put(conn, ~p"/staff/meetings/#{meeting}", meeting: params)

      assert html_response(conn, 200) =~ "Edit Meeting"
    end
  end

  describe "delete meeting" do
    test "deletes chosen meeting", %{conn: conn, meeting: meeting} do
      conn = delete(conn, ~p"/staff/meetings/#{meeting}")

      assert redirected_to(conn) == ~p"/staff/courses/#{meeting.course_id}/meetings"

      conn = get(conn, ~p"/staff/meetings/#{meeting}")
      assert redirected_to(conn) == ~p"/"
    end
  end
end
