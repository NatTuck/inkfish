defmodule InkfishWeb.Staff.MeetingControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.MeetingsFixtures

  @create_attrs %{started_at: ~U[2025-08-02 19:37:00Z]}
  @update_attrs %{started_at: ~U[2025-08-03 19:37:00Z]}
  @invalid_attrs %{started_at: nil}

  describe "index" do
    test "lists all meetings", %{conn: conn} do
      conn = get(conn, ~p"/staff/meetings")
      assert html_response(conn, 200) =~ "Listing Meetings"
    end
  end

  describe "new meeting" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/staff/meetings/new")
      assert html_response(conn, 200) =~ "New Meeting"
    end
  end

  describe "create meeting" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/staff/meetings", meeting: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/staff/meetings/#{id}"

      conn = get(conn, ~p"/staff/meetings/#{id}")
      assert html_response(conn, 200) =~ "Meeting #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/staff/meetings", meeting: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Meeting"
    end
  end

  describe "edit meeting" do
    setup [:create_meeting]

    test "renders form for editing chosen meeting", %{conn: conn, meeting: meeting} do
      conn = get(conn, ~p"/staff/meetings/#{meeting}/edit")
      assert html_response(conn, 200) =~ "Edit Meeting"
    end
  end

  describe "update meeting" do
    setup [:create_meeting]

    test "redirects when data is valid", %{conn: conn, meeting: meeting} do
      conn = put(conn, ~p"/staff/meetings/#{meeting}", meeting: @update_attrs)
      assert redirected_to(conn) == ~p"/staff/meetings/#{meeting}"

      conn = get(conn, ~p"/staff/meetings/#{meeting}")
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, meeting: meeting} do
      conn = put(conn, ~p"/staff/meetings/#{meeting}", meeting: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Meeting"
    end
  end

  describe "delete meeting" do
    setup [:create_meeting]

    test "deletes chosen meeting", %{conn: conn, meeting: meeting} do
      conn = delete(conn, ~p"/staff/meetings/#{meeting}")
      assert redirected_to(conn) == ~p"/staff/meetings"

      assert_error_sent 404, fn ->
        get(conn, ~p"/staff/meetings/#{meeting}")
      end
    end
  end

  defp create_meeting(_) do
    meeting = meeting_fixture()
    %{meeting: meeting}
  end
end
