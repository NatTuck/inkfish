defmodule InkfishWeb.ApiV1.Staff.SubControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.Factory

  # Setup for all tests in this module
  setup %{conn: conn} do
    course = insert(:course)

    {:ok,
     conn: put_req_header(conn, "accept", "application/json"), course: course}
  end

  # Helper to create a user with an API key and return a conn with the x-auth header
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

  # Helper to create a sub for a specific user in a given course
  defp create_sub_for_user(user, course, assignment_attrs \\ %{}) do
    bucket = insert(:bucket, course: course)
    teamset = insert(:teamset, course: course)

    assignment =
      insert(
        :assignment,
        Map.merge(assignment_attrs, %{bucket: bucket, teamset: teamset})
      )

    reg = insert(:reg, user: user, course: course)
    team = insert(:team, teamset: teamset)
    insert(:team_member, team: team, reg: reg)
    upload = insert(:upload, user: user)

    sub =
      insert(:sub, assignment: assignment, reg: reg, team: team, upload: upload)

    %{
      sub: sub,
      user: user,
      assignment: assignment,
      reg: reg,
      team: team,
      upload: upload
    }
  end

  describe "index" do
    test "requires assignment_id", %{conn: conn} do
      # An API key IS needed because of the RequireApiUser plug
      %{conn: conn} = logged_in_user_with_api_key(conn)

      conn = get(conn, ~p"/api/v1/staff/subs")

      assert json_response(conn, 404)
    end

    test "staff/prof user can list all subs for a given assignment", %{
      conn: conn,
      course: course
    } do
      # Setup staff user and API key
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      staff_reg = insert(:reg, user: staff_user, course: course, is_staff: true)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      assignment = insert(:assignment, bucket: bucket, teamset: teamset)

      staff_user_sub =
        insert(:sub,
          assignment: assignment,
          reg: staff_reg,
          team: insert(:team, teamset: teamset),
          upload: insert(:upload, user: staff_user)
        )

      other_user = insert(:user)
      other_reg = insert(:reg, user: other_user, course: course)
      other_team = insert(:team, teamset: teamset)
      insert(:team_member, team: other_team, reg: other_reg)

      other_sub =
        insert(:sub,
          assignment: assignment,
          reg: other_reg,
          team: other_team,
          upload: insert(:upload, user: other_user)
        )

      conn =
        get(staff_conn, ~p"/api/v1/staff/subs", %{
          assignment_id: assignment.id
        })

      response_ids =
        json_response(conn, 200)["data"] |> Enum.map(& &1["id"]) |> Enum.sort()

      expected_ids = [staff_user_sub.id, other_sub.id] |> Enum.sort()
      assert response_ids == expected_ids
    end

    test "non-staff/prof user cannot list subs for a given assignment", %{
      conn: conn,
      course: course
    } do
      # Setup student user and API key
      %{conn: student_conn, user: student_user} =
        logged_in_user_with_api_key(conn)

      insert(:reg, user: student_user, course: course, is_student: true)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      assignment = insert(:assignment, bucket: bucket, teamset: teamset)

      conn =
        get(student_conn, ~p"/api/v1/staff/subs", %{
          assignment_id: assignment.id
        })

      assert json_response(conn, 403)["error"] == "Access denied"
    end
  end

  describe "show sub" do
    test "staff user can see any sub in their course", %{
      conn: conn,
      course: course
    } do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      student_user = insert(:user)
      %{sub: student_sub} = create_sub_for_user(student_user, course)

      conn = get(staff_conn, ~p"/api/v1/staff/subs/#{student_sub.id}")
      assert json_response(conn, 200)["data"]["id"] == student_sub.id
    end

    test "prof user can see any sub in their course", %{
      conn: conn,
      course: course
    } do
      %{conn: prof_conn, user: prof_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: prof_user, course: course, is_prof: true)

      student_user = insert(:user)
      %{sub: student_sub} = create_sub_for_user(student_user, course)

      conn = get(prof_conn, ~p"/api/v1/staff/subs/#{student_sub.id}")
      assert json_response(conn, 200)["data"]["id"] == student_sub.id
    end

    test "staff/prof user cannot see a sub in a different course", %{conn: conn} do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      course_a = insert(:course)
      insert(:reg, user: staff_user, course: course_a, is_staff: true)

      course_b = insert(:course)
      student_user = insert(:user)

      %{sub: student_sub_in_course_b} =
        create_sub_for_user(student_user, course_b)

      conn =
        get(staff_conn, ~p"/api/v1/staff/subs/#{student_sub_in_course_b.id}")

      assert json_response(conn, 403)["error"] == "Access denied"
    end

    test "returns 404 for non-existent sub", %{conn: conn, course: course} do
      %{conn: conn, user: user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: user, course: course, is_staff: true)
      # Use a large integer for a non-existent ID
      non_existent_id = 9_999_999_999

      assert_raise Ecto.NoResultsError, fn ->
        get(conn, ~p"/api/v1/staff/subs/#{non_existent_id}")
      end
    end
  end
end
