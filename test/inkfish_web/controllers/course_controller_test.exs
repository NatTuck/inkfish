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

    test "shows correct bucket total for student with multiple submissions", %{
      conn: conn
    } do
      # Create a complete course structure with assignments, submissions, and grades
      course_data = create_course_with_assignments_and_submissions()
      course = course_data.course
      student = course_data.student

      conn =
        conn
        |> login(student.email)
        |> get(~p"/courses/#{course}")

      response = html_response(conn, 200)

      # Check that the bucket total is calculated correctly
      # Based on the setup, this should be 90% (45/50 points across assignments)
      assert response =~ "90.0%"
    end
  end

  defp create_course_with_team(_) do
    course = insert(:course)
    {:ok, course: course}
  end

  defp create_course_with_assignments_and_submissions() do
    # Create course with bucket
    course = insert(:course)
    bucket = insert(:bucket, course_id: course.id, weight: Decimal.new("1.0"))

    # Create student
    student = insert(:user, email: "student@example.com")

    student_reg =
      insert(:reg,
        user_id: student.id,
        course_id: course.id,
        is_student: true
      )

    # Create team for student
    teamset_id = course.solo_teamset_id
    team = insert(:team, teamset_id: teamset_id, active: true)
    insert(:team_member, team_id: team.id, reg_id: student_reg.id)

    # Create assignments with grade columns
    assignment1 =
      insert(:assignment,
        bucket_id: bucket.id,
        teamset_id: teamset_id,
        weight: Decimal.new("1.0"),
        name: "Assignment 1"
      )

    assignment2 =
      insert(:assignment,
        bucket_id: bucket.id,
        teamset_id: teamset_id,
        weight: Decimal.new("1.0"),
        name: "Assignment 2"
      )

    # Create grade columns for assignments
    gcol1 =
      insert(:grade_column,
        assignment_id: assignment1.id,
        points: Decimal.new("25.0")
      )

    gcol2 =
      insert(:grade_column,
        assignment_id: assignment2.id,
        points: Decimal.new("25.0")
      )

    # Create submissions
    sub1 =
      insert(:sub,
        assignment_id: assignment1.id,
        reg_id: student_reg.id,
        team_id: team.id,
        active: true,
        # 80% of 25
        score: Decimal.new("20.0")
      )

    sub2 =
      insert(:sub,
        assignment_id: assignment2.id,
        reg_id: student_reg.id,
        team_id: team.id,
        active: true,
        # 100% of 25
        score: Decimal.new("25.0")
      )

    # Create grades
    insert(:grade,
      grade_column_id: gcol1.id,
      sub_id: sub1.id,
      score: Decimal.new("20.0")
    )

    insert(:grade,
      grade_column_id: gcol2.id,
      sub_id: sub2.id,
      score: Decimal.new("25.0")
    )

    %{
      course: course,
      student: student,
      assignments: [assignment1, assignment2],
      submissions: [sub1, sub2]
    }
  end
end
