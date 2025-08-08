defmodule InkfishWeb.MeetingControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.Factory

  describe "index" do
    setup [:create_course_and_reg]

    test "lists all meetings", %{conn: conn, course: course, reg: reg} do
      # Create a meeting for the course
      insert(:meeting, course: course)
      
      # Login as the user
      conn = login(conn, reg.user)
      
      conn = get(conn, ~p"/courses/#{course}/meetings")
      assert html_response(conn, 200) =~ "Meetings"
    end

    test "redirects when not logged in", %{conn: conn, course: course} do
      conn = get(conn, ~p"/courses/#{course}/meetings")
      assert redirected_to(conn) == "/"
    end
  end

  defp create_course_and_reg(_) do
    course = insert(:course)
    user = insert(:user)
    reg = insert(:reg, course: course, user: user, is_student: true)
    %{course: course, reg: reg, user: user}
  end
end
