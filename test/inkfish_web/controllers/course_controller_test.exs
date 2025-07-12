defmodule InkfishWeb.CourseControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  def fixture(:course) do
    insert(:course)
  end

  describe "index" do
    test "lists all courses", %{conn: conn} do
      conn =
        conn
        |> login("erin@example.com")
        |> get(~p"/courses")

      assert html_response(conn, 200) =~ "Listing Courses"
    end
  end

  describe "show course" do
    setup [:create_course]

    test "shows chosen course", %{conn: conn, course: course} do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/courses/#{course}")

      assert html_response(conn, 200) =~ course.name
    end
  end

  defp create_course(_) do
    course = fixture(:course)
    {:ok, course: course}
  end
end
