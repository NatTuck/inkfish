defmodule InkfishWeb.ApiV1.Staff.CourseControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.Factory

  setup %{conn: conn} do
    course = insert(:course)

    {:ok,
     conn: put_req_header(conn, "accept", "application/json"), course: course}
  end

  defp logged_in_user_with_api_key(
         conn,
         user_attrs \\ %{},
         api_key_attrs \\ %{}
       ) do
    user = insert(:user, user_attrs)
    api_key = insert(:api_key, Map.put(api_key_attrs, :user, user))
    conn = put_req_header(conn, "x-auth", api_key.key)
    %{conn: conn, user: user, api_key: api_key}
  end

  describe "show course" do
    test "staff user can view their course", %{conn: conn, course: course} do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      _bucket = insert(:bucket, course: course)
      _teamset = insert(:teamset, course: course)

      conn = get(staff_conn, ~p"/api/v1/staff/courses/#{course.id}")
      response = json_response(conn, 200)

      assert %{"data" => %{"id" => course_id, "name" => _}} = response
      assert course_id == course.id
      assert %{"buckets" => [_]} = response["data"]
      assert %{"teamsets" => [_]} = response["data"]
    end

    test "prof user can view their course", %{conn: conn, course: course} do
      %{conn: prof_conn, user: prof_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: prof_user, course: course, is_prof: true)

      conn = get(prof_conn, ~p"/api/v1/staff/courses/#{course.id}")
      response = json_response(conn, 200)

      assert %{"data" => %{"id" => course_id}} = response
      assert course_id == course.id
    end

    test "non-staff user cannot view course", %{conn: conn, course: course} do
      %{conn: student_conn, user: student_user} =
        logged_in_user_with_api_key(conn)

      insert(:reg, user: student_user, course: course, is_student: true)

      conn = get(student_conn, ~p"/api/v1/staff/courses/#{course.id}")
      assert json_response(conn, 403)["error"] == "Access denied"
    end

    test "user not registered in course cannot view", %{
      conn: conn,
      course: course
    } do
      %{conn: user_conn, user: _user} = logged_in_user_with_api_key(conn)

      conn = get(user_conn, ~p"/api/v1/staff/courses/#{course.id}")
      assert json_response(conn, 403)["error"] == "Registration required"
    end

    test "returns 404 for non-existent course", %{conn: conn} do
      %{conn: conn, user: user} = logged_in_user_with_api_key(conn)
      course = insert(:course)
      insert(:reg, user: user, course: course, is_staff: true)

      non_existent_id = 9_999_999_999

      conn = get(conn, ~p"/api/v1/staff/courses/#{non_existent_id}")
      assert json_response(conn, 404)
    end

    test "requires valid API key", %{conn: conn, course: course} do
      conn = put_req_header(conn, "x-auth", "invalid-key")

      conn = get(conn, ~p"/api/v1/staff/courses/#{course.id}")
      assert json_response(conn, 403)
    end

    test "response includes solo_teamset_id", %{conn: conn} do
      course = insert(:course)
      solo_teamset = Inkfish.Teams.create_solo_teamset!(course)
      course = Inkfish.Courses.get_course!(course.id)

      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      conn = get(staff_conn, ~p"/api/v1/staff/courses/#{course.id}")
      response = json_response(conn, 200)

      assert %{"data" => %{"solo_teamset_id" => solo_id}} = response
      assert solo_id == solo_teamset.id
    end
  end

  describe "gradesheet" do
    test "staff user can view gradesheet for their course", %{conn: conn} do
      course = insert(:course)

      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      bucket = insert(:bucket, course: course)
      assignment = insert(:assignment, bucket: bucket)

      student_user = insert(:user, given_name: "Alice", surname: "Smith")

      student_reg =
        insert(:reg, user: student_user, course: course, is_student: true)

      teamset = insert(:teamset, course: course)
      team = insert(:team, teamset: teamset)
      insert(:team_member, team: team, reg: student_reg)

      sub = insert(:sub, assignment: assignment, reg: student_reg, team: team)

      # Create active_sub record for the new logic
      insert(:active_sub,
        reg: student_reg,
        assignment: assignment,
        sub: sub
      )

      _grade_col =
        insert(:grade_column,
          assignment: assignment,
          kind: "number",
          points: Decimal.new("100")
        )

      _grade =
        insert(:grade,
          sub: sub,
          grade_column:
            insert(:grade_column,
              assignment: assignment,
              kind: "number",
              points: Decimal.new("100")
            ),
          score: Decimal.new("85")
        )

      conn = get(staff_conn, ~p"/api/v1/staff/courses/#{course.id}/gradesheet")
      response = json_response(conn, 200)

      assert response["course"]["id"] == course.id
      assert response["course"]["name"] == course.name

      assert is_map(response["students"])
      assert is_map(response["buckets"])
      assert is_map(response["stats"])

      student_key = to_string(student_reg.id)
      assert response["students"][student_key]["name"] == "Alice Smith"

      bucket_key = to_string(bucket.id)
      assert response["buckets"][bucket_key]["name"] == bucket.name
      assert response["buckets"][bucket_key]["weight"] == "1.0"

      assignment_key = to_string(assignment.id)

      assert response["buckets"][bucket_key]["assignments"][assignment_key][
               "name"
             ] == assignment.name
    end

    test "non-staff user cannot view gradesheet", %{conn: conn, course: course} do
      %{conn: student_conn, user: student_user} =
        logged_in_user_with_api_key(conn)

      insert(:reg, user: student_user, course: course, is_student: true)

      conn =
        get(student_conn, ~p"/api/v1/staff/courses/#{course.id}/gradesheet")

      assert json_response(conn, 403)["error"] == "Access denied"
    end

    test "user not registered in course cannot view gradesheet", %{
      conn: conn,
      course: course
    } do
      %{conn: user_conn, user: _user} = logged_in_user_with_api_key(conn)

      conn = get(user_conn, ~p"/api/v1/staff/courses/#{course.id}/gradesheet")
      assert json_response(conn, 403)["error"] == "Registration required"
    end
  end
end
