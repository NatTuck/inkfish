defmodule InkfishWeb.Staff.MeetingsControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.MeetingFixtures

  @create_attrs %{started_at: ~U[2025-08-02 18:39:00Z]}
  @update_attrs %{started_at: ~U[2025-08-03 18:39:00Z]}
  @invalid_attrs %{started_at: nil}

  describe "index" do
    test "lists all meetings", %{conn: conn} do
      conn = get(conn, ~p"/meetings")
      assert html_response(conn, 200) =~ "Listing Meetings"
    end
  end

  describe "new meetings" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/meetings/new")
      assert html_response(conn, 200) =~ "New Meetings"
    end
  end

  describe "create meetings" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/meetings", meetings: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/meetings/#{id}"

      conn = get(conn, ~p"/meetings/#{id}")
      assert html_response(conn, 200) =~ "Meetings #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/meetings", meetings: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Meetings"
    end
  end

  describe "edit meetings" do
    setup [:create_meetings]

    test "renders form for editing chosen meetings", %{
      conn: conn,
      meetings: meetings
    } do
      conn = get(conn, ~p"/meetings/#{meetings}/edit")
      assert html_response(conn, 200) =~ "Edit Meetings"
    end
  end

  describe "update meetings" do
    setup [:create_meetings]

    test "redirects when data is valid", %{conn: conn, meetings: meetings} do
      conn = put(conn, ~p"/meetings/#{meetings}", meetings: @update_attrs)
      assert redirected_to(conn) == ~p"/meetings/#{meetings}"

      conn = get(conn, ~p"/meetings/#{meetings}")
      assert html_response(conn, 200)
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      meetings: meetings
    } do
      conn = put(conn, ~p"/meetings/#{meetings}", meetings: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Meetings"
    end
  end

  describe "delete meetings" do
    setup [:create_meetings]

    test "deletes chosen meetings", %{conn: conn, meetings: meetings} do
      conn = delete(conn, ~p"/meetings/#{meetings}")
      assert redirected_to(conn) == ~p"/meetings"

      assert_error_sent 404, fn ->
        get(conn, ~p"/meetings/#{meetings}")
      end
    end
  end

  defp create_meetings(_) do
    meetings = meetings_fixture()
    %{meetings: meetings}
  end
end
