defmodule InkfishWeb.Staff.JoinReqControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    %{staff: staff, course: course} = stock_course()
    user = insert(:user)
    jr = insert(:join_req, course: course, user: user)
    conn = login(conn, staff)
    {:ok, conn: conn, course: course, user: user, join_req: jr}
  end

  describe "index" do
    test "lists all join_reqs", %{conn: conn, course: course} do
      conn = get(conn, ~p"/staff/courses/#{course}/join_reqs")
      assert html_response(conn, 200) =~ "Listing Join Requests"
    end
  end

  describe "delete join_req" do
    test "deletes chosen join_req", %{conn: conn, join_req: join_req} do
      conn = delete(conn, ~p"/staff/join_reqs/#{join_req}")

      assert redirected_to(conn) ==
               ~p"/staff/courses/#{join_req.course_id}/join_reqs"

      conn = get(conn, ~p"/staff/join_reqs/#{join_req}")
      assert redirected_to(conn) == ~p"/"
    end
  end
end
