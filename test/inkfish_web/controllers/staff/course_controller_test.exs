defmodule InkfishWeb.Staff.CourseControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  # alias Inkfish.Courses

  setup %{conn: conn} do
    course = insert(:course)
    staff = insert(:user)
    _sr = insert(:reg, course: course, user: staff, is_staff: true)
    conn = login(conn, staff)
    {:ok, conn: conn, course: course, staff: staff}
  end

  describe "index" do
    test "lists all courses", %{conn: conn, course: _course} do
      conn = get(conn, ~p"/staff/courses")
      assert html_response(conn, 200) =~ "Listing Courses"
    end
  end

  describe "gradesheet" do
    test "renders", %{conn: conn, course: course} do
      conn = get(conn, ~p"/staff/courses/#{course}/gradesheet")
      assert html_response(conn, 200) =~ "Gradesheet"
    end
  end

  describe "edit course" do
    test "renders form for editing chosen course", %{conn: conn, course: course} do
      conn = get(conn, ~p"/staff/courses/#{course}/edit")
      assert html_response(conn, 200) =~ "Edit Course"
    end
  end

  describe "update course" do
    test "redirects when data is valid", %{conn: conn, course: course} do
      conn =
        put(conn, ~p"/staff/courses/#{course}",
          course: %{footer: "some updated footer"}
        )

      assert redirected_to(conn) ==
               ~p"/staff/courses/#{course}"

      conn = get(conn, ~p"/staff/courses/#{course}")
      assert html_response(conn, 200) =~ "some updated footer"
    end

    test "renders errors when data is invalid", %{conn: conn, course: course} do
      conn =
        put(conn, ~p"/staff/courses/#{course}",
          course: %{name: "x"}
        )

      assert html_response(conn, 200) =~ "Edit Course"
    end
  end
end
