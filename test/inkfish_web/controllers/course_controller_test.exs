defmodule InkfishWeb.CourseControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

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
    setup [:create_course_with_team]

    test "shows chosen course", %{conn: conn, course: course} do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/courses/#{course}")

      assert html_response(conn, 200) =~ course.name
    end
  end

  defp create_course_with_team(_) do
    course = insert(:course)
    user = insert(:user, email: "alice@example.com")
    reg = insert(:reg, course: course, user: user)
    teamset = insert(:teamset, course: course)
    team = insert(:team, teamset: teamset, active: true)
    insert(:team_member, team: team, reg: reg)
    
    # Reload course and reg to ensure associations are set up
    course = Inkfish.Repo.preload(course, :teamsets)
    reg = Inkfish.Repo.preload(reg, :teams)
    
    {:ok, course: course, reg: reg}
  end
end
