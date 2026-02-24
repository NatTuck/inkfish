defmodule InkfishWeb.ApiV1.Staff.DashboardControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.Factory

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index dashboard" do
    test "staff user can see dashboard for their courses", %{conn: conn} do
      # Create staff user with API key
      user = insert(:user)
      api_key = insert(:api_key, user: user)
      conn = put_req_header(conn, "x-auth", api_key.key)

      # Create a course with the staff
      course = insert(:course)
      insert(:reg, user: user, course: course, is_staff: true)

      # Create buckets and assignments
      bucket1 = insert(:bucket, course: course, name: "Homework")
      teamset = insert(:teamset, course: course)

      # Past assignment with ungraded submissions (due 5 days ago)
      past_asg =
        insert(:assignment,
          bucket: bucket1,
          teamset: teamset,
          name: "Past HW",
          due: Inkfish.LocalTime.in_days(-5)
        )

      insert(:grade_column,
        assignment: past_asg,
        kind: "feedback",
        name: "Feedback",
        points: "10",
        base: "0"
      )

      conn = get(conn, ~p"/api/v1/staff/dashboard")
      response = json_response(conn, 200)

      assert %{"courses" => [course_data]} = response
      assert course_data["id"] == course.id
      assert course_data["name"] == course.name

      # Should have past assignments with ungraded
      assert is_list(course_data["past_assignments_with_ungraded"])
      past_asgs = course_data["past_assignments_with_ungraded"]
      assert length(past_asgs) == 1
      assert hd(past_asgs)["name"] == "Past HW"

      # Should have upcoming by bucket
      assert %{"Homework" => upcoming} = course_data["upcoming_by_bucket"]
      assert upcoming == []
    end

    test "prof user can see dashboard for their courses", %{conn: conn} do
      user = insert(:user)
      api_key = insert(:api_key, user: user)
      conn = put_req_header(conn, "x-auth", api_key.key)

      course = insert(:course)
      insert(:reg, user: user, course: course, is_prof: true)

      conn = get(conn, ~p"/api/v1/staff/dashboard")
      response = json_response(conn, 200)

      assert %{"courses" => [course_data]} = response
      assert course_data["id"] == course.id
    end

    test "non-staff user cannot access dashboard", %{conn: conn} do
      user = insert(:user)
      api_key = insert(:api_key, user: user)
      conn = put_req_header(conn, "x-auth", api_key.key)

      # Create course with student
      course = insert(:course)
      insert(:reg, user: user, course: course, is_student: true)

      conn = get(conn, ~p"/api/v1/staff/dashboard")
      assert json_response(conn, 403)
    end

    test "user with no courses sees empty list", %{conn: conn} do
      user = insert(:user)
      api_key = insert(:api_key, user: user)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn = get(conn, ~p"/api/v1/staff/dashboard")
      response = json_response(conn, 200)

      assert %{"courses" => []} = response
    end

    test "returns past assignments with ungraded count", %{conn: conn} do
      user = insert(:user)
      api_key = insert(:api_key, user: user)
      conn = put_req_header(conn, "x-auth", api_key.key)

      course = insert(:course)
      insert(:reg, user: user, course: course, is_staff: true)

      bucket = insert(:bucket, course: course, name: "Homework")
      teamset = insert(:teamset, course: course)

      # Past assignment (due 5 days ago)
      past_asg =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          name: "Past HW",
          due: Inkfish.LocalTime.in_days(-5)
        )

      insert(:grade_column,
        assignment: past_asg,
        kind: "feedback",
        name: "Feedback",
        points: "10",
        base: "0"
      )

      # Create a student, team, and submission
      student = insert(:user)

      student_reg =
        insert(:reg, user: student, course: course, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)

      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: past_asg,
          reg: student_reg,
          team: team,
          upload: upload,
          active: true
        )

      # No grade - so should be ungraded
      conn = get(conn, ~p"/api/v1/staff/dashboard")
      response = json_response(conn, 200)

      [course_data] = response["courses"]
      [past] = course_data["past_assignments_with_ungraded"]

      assert past["ungraded_count"] == 1
      assert past["total_count"] == 1
      assert past["overdue"] == true
    end

    test "overdue is false when assignment is past but less than 4 days old", %{
      conn: conn
    } do
      user = insert(:user)
      api_key = insert(:api_key, user: user)
      conn = put_req_header(conn, "x-auth", api_key.key)

      course = insert(:course)
      insert(:reg, user: user, course: course, is_staff: true)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)

      # Past assignment (due 2 days ago - not overdue yet)
      asg =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          name: "Recent Past",
          due: Inkfish.LocalTime.in_days(-2)
        )

      insert(:grade_column,
        assignment: asg,
        kind: "feedback",
        name: "Feedback",
        points: "10",
        base: "0"
      )

      # Create submission
      student = insert(:user)

      student_reg =
        insert(:reg, user: student, course: course, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)
      upload = insert(:upload, user: student)

      insert(:sub,
        assignment: asg,
        reg: student_reg,
        team: team,
        upload: upload,
        active: true
      )

      conn = get(conn, ~p"/api/v1/staff/dashboard")
      response = json_response(conn, 200)

      [course_data] = response["courses"]
      [past] = course_data["past_assignments_with_ungraded"]

      assert past["overdue"] == false
    end

    test "includes upcoming assignments grouped by bucket", %{conn: conn} do
      user = insert(:user)
      api_key = insert(:api_key, user: user)
      conn = put_req_header(conn, "x-auth", api_key.key)

      course = insert(:course)
      insert(:reg, user: user, course: course, is_staff: true)

      bucket1 = insert(:bucket, course: course, name: "Homework")
      bucket2 = insert(:bucket, course: course, name: "Projects")
      teamset = insert(:teamset, course: course)

      # Upcoming homework 1 (due in 3 days)
      hw1 =
        insert(:assignment,
          bucket: bucket1,
          teamset: teamset,
          name: "HW 1",
          due: Inkfish.LocalTime.in_days(3)
        )

      # Upcoming homework 2 (due in 10 days)
      insert(:assignment,
        bucket: bucket1,
        teamset: teamset,
        name: "HW 2",
        due: Inkfish.LocalTime.in_days(10)
      )

      # Upcoming project (due in 20 days)
      insert(:assignment,
        bucket: bucket2,
        teamset: teamset,
        name: "Project 1",
        due: Inkfish.LocalTime.in_days(20)
      )

      conn = get(conn, ~p"/api/v1/staff/dashboard")
      response = json_response(conn, 200)

      [course_data] = response["courses"]
      upcoming = course_data["upcoming_by_bucket"]

      # Should have both buckets
      assert upcoming["Homework"]
      assert upcoming["Projects"]

      # Homework should have 2 upcoming (ordered by due date)
      assert length(upcoming["Homework"]) == 2
      assert hd(upcoming["Homework"])["name"] == "HW 1"

      # Projects should have 1 upcoming
      assert length(upcoming["Projects"]) == 1
    end

    test "includes empty buckets with no upcoming assignments", %{conn: conn} do
      user = insert(:user)
      api_key = insert(:api_key, user: user)
      conn = put_req_header(conn, "x-auth", api_key.key)

      course = insert(:course)
      insert(:reg, user: user, course: course, is_staff: true)

      # Bucket with only past assignments
      bucket = insert(:bucket, course: course, name: "Past Only")
      teamset = insert(:teamset, course: course)

      insert(:assignment,
        bucket: bucket,
        teamset: teamset,
        name: "Old HW",
        due: Inkfish.LocalTime.in_days(-10)
      )

      conn = get(conn, ~p"/api/v1/staff/dashboard")
      response = json_response(conn, 200)

      [course_data] = response["courses"]
      upcoming = course_data["upcoming_by_bucket"]

      assert upcoming["Past Only"] == []
    end

    test "assignments with all grades are not included in past ungraded", %{
      conn: conn
    } do
      user = insert(:user)
      api_key = insert(:api_key, user: user)
      conn = put_req_header(conn, "x-auth", api_key.key)

      course = insert(:course)
      insert(:reg, user: user, course: course, is_staff: true)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)

      # Past assignment
      past_asg =
        insert(:assignment,
          bucket: bucket,
          teamset: teamset,
          name: "Fully Graded",
          due: Inkfish.LocalTime.in_days(-5)
        )

      grade_col =
        insert(:grade_column,
          assignment: past_asg,
          kind: "feedback",
          name: "Feedback",
          points: "10",
          base: "0"
        )

      # Create student and submission WITH grade
      student = insert(:user)

      student_reg =
        insert(:reg, user: student, course: course, is_student: true)

      team = insert(:team, teamset: teamset, active: true)
      insert(:team_member, team: team, reg: student_reg)
      upload = insert(:upload, user: student)

      sub =
        insert(:sub,
          assignment: past_asg,
          reg: student_reg,
          team: team,
          upload: upload,
          active: true
        )

      # Create a grade for the submission
      insert(:grade, sub: sub, grade_column: grade_col, score: Decimal.new("8"))

      conn = get(conn, ~p"/api/v1/staff/dashboard")
      response = json_response(conn, 200)

      [course_data] = response["courses"]

      # Should not include this assignment since it's fully graded
      past_assignments = course_data["past_assignments_with_ungraded"]
      assert past_assignments == []
    end

    test "requires valid API key", %{conn: conn} do
      conn = put_req_header(conn, "x-auth", "invalid-key")

      conn = get(conn, ~p"/api/v1/staff/dashboard")
      assert json_response(conn, 403)
    end
  end
end
