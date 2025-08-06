defmodule InkfishWeb.MeetingControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.Factory

  @create_attrs %{started_at: ~U[2025-08-02 19:36:00Z]}
  @update_attrs %{started_at: ~U[2025-08-03 19:36:00Z]}
  @invalid_attrs %{started_at: nil}

  describe "index" do
    setup [:create_course]

    test "lists all meetings", %{conn: conn, course: course} do
      conn = get(conn, ~p"/courses/#{course}/meetings")
      assert html_response(conn, 200) =~ "Listing Meetings"
    end
  end

  describe "new meeting" do
    setup [:create_course]

    test "renders form", %{conn: conn, course: course} do
      conn = get(conn, ~p"/courses/#{course}/meetings/new")
      assert html_response(conn, 200) =~ "New Meeting"
    end
  end

  describe "create meeting" do
    setup [:create_course]

    test "redirects to show when data is valid", %{conn: conn, course: course} do
      conn = post(conn, ~p"/courses/#{course}/meetings", meeting: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/courses/#{course}/meetings/#{id}"

      conn = get(conn, ~p"/courses/#{course}/meetings/#{id}")
      assert html_response(conn, 200) =~ "Meeting #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn, course: course} do
      conn = post(conn, ~p"/courses/#{course}/meetings", meeting: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Meeting"
    end
  end

  describe "edit meeting" do
    setup [:create_meeting_with_course]

    test "renders form for editing chosen meeting", %{
      conn: conn,
      meeting: meeting,
      course: course
    } do
      conn = get(conn, ~p"/courses/#{course}/meetings/#{meeting}/edit")
      assert html_response(conn, 200) =~ "Edit Meeting"
    end
  end

  describe "update meeting" do
    setup [:create_meeting_with_course]

    test "redirects when data is valid", %{conn: conn, meeting: meeting, course: course} do
      conn = put(conn, ~p"/courses/#{course}/meetings/#{meeting}", meeting: @update_attrs)
      assert redirected_to(conn) == ~p"/courses/#{course}/meetings/#{meeting}"

      conn = get(conn, ~p"/courses/#{course}/meetings/#{meeting}")
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, meeting: meeting, course: course} do
      conn = put(conn, ~p"/courses/#{course}/meetings/#{meeting}", meeting: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Meeting"
    end
  end

  describe "delete meeting" do
    setup [:create_meeting_with_course]

    test "deletes chosen meeting", %{conn: conn, meeting: meeting, course: course} do
      conn = delete(conn, ~p"/courses/#{course}/meetings/#{meeting}")
      assert redirected_to(conn) == ~p"/courses/#{course}/meetings"

      assert_error_sent 404, fn ->
        get(conn, ~p"/courses/#{course}/meetings/#{meeting}")
      end
    end
  end

  defp create_course(_) do
    course = insert(:course)
    %{course: course}
  end

  defp create_meeting_with_course(_) do
    course = insert(:course)
    meeting = insert(:meeting, course: course)
    %{meeting: meeting, course: course}
  end
end
