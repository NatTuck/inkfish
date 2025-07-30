defmodule InkfishWeb.Staff.TeamsetControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    course = insert(:course)
    staff = insert(:user)
    _sr = insert(:reg, course: course, user: staff, is_staff: true)
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
end
