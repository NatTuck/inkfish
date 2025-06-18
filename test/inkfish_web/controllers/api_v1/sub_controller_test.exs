defmodule InkfishWeb.ApiV1.SubControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.Factory

  alias Inkfish.Subs.Sub
  # Removed unused alias: alias Inkfish.Repo

  @create_attrs %{
    active: true,
    late_penalty: "120.5",
    score: "120.5",
    hours_spent: "120.5",
    note: "some note",
    ignore_late_penalty: true
  }
  @update_attrs %{
    active: false,
    late_penalty: "456.7",
    score: "456.7",
    hours_spent: "456.7",
    note: "some updated note",
    ignore_late_penalty: false
  }
  @invalid_attrs %{
    active: nil,
    late_penalty: nil,
    score: nil,
    hours_spent: nil,
    note: nil,
    ignore_late_penalty: nil
  }

  # Setup for all tests in this module
  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
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

    %{sub: sub, user: user, assignment: assignment, reg: reg, team: team, upload: upload}
  end

  # Helper to create a sub for create/update tests, ensuring it belongs to the authenticated user
  defp create_sub_for_test(%{conn: conn}) do
    %{conn: authenticated_conn, user: user} = logged_in_user_with_api_key(conn)
    course = insert(:course)
    %{sub: sub, assignment: assignment, reg: reg, team: team, upload: upload} =
      create_sub_for_user(user, course)

    %{
      conn: authenticated_conn, # Return the authenticated conn
      sub: sub,
      user: user,
      assignment: assignment,
      reg: reg,
      team: team,
      upload: upload
    }
  end

  describe "index" do
    setup %{conn: conn} do
      # Create a course for all index tests
      course = insert(:course)
      %{conn: conn, course: course}
    end

    test "requires assignment_id", %{conn: conn} do
      # An API key IS needed because of the RequireApiUser plug
      %{conn: conn} = logged_in_user_with_api_key(conn)
      # Corrected path and expected status
      conn = get(conn, ~p"/api/v1/subs")
      assert json_response(conn, 400)["error"] == "assignment_id is required"
    end

    test "lists only current user's subs for a given assignment", %{
      conn: conn,
      course: course
    } do
      # Setup user and API key
      %{conn: conn, user: user} = logged_in_user_with_api_key(conn)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      assignment = insert(:assignment, bucket: bucket, teamset: teamset)

      reg = insert(:reg, user: user, course: course)
      team = insert(:team, teamset: teamset)
      insert(:team_member, team: team, reg: reg)
      user_sub =
        insert(:sub,
          assignment: assignment,
          reg: reg,
          team: team,
          upload: insert(:upload, user: user)
        )

      other_user = insert(:user)
      other_reg = insert(:reg, user: other_user, course: course)
      other_team = insert(:team, teamset: teamset)
      insert(:team_member, team: other_team, reg: other_reg)
      _other_sub =
        insert(:sub,
          assignment: assignment,
          reg: other_reg,
          team: other_team,
          upload: insert(:upload, user: other_user)
        )

      conn = get(conn, ~p"/api/v1/subs", %{assignment_id: assignment.id})

      assert json_response(conn, 200)["data"]
             |> Enum.map(& &1["id"])
             |> Enum.sort() == [user_sub.id] |> Enum.sort()
    end

    test "staff/prof user can list all subs for a given assignment with 'all' parameter",
         %{conn: conn, course: course} do
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
        get(staff_conn, ~p"/api/v1/subs", %{assignment_id: assignment.id, all: "true"})

      response_ids =
        json_response(conn, 200)["data"] |> Enum.map(& &1["id"]) |> Enum.sort()

      expected_ids = [staff_user_sub.id, other_sub.id] |> Enum.sort()
      assert response_ids == expected_ids
    end

    test "non-staff/prof user cannot list all subs for a given assignment with 'all' parameter",
         %{conn: conn, course: course} do
      # Setup student user and API key
      %{conn: student_conn, user: student_user} = logged_in_user_with_api_key(conn)
      student_reg = insert(:reg, user: student_user, course: course, is_student: true)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      assignment = insert(:assignment, bucket: bucket, teamset: teamset)

      student_user_sub =
        insert(:sub,
          assignment: assignment,
          reg: student_reg,
          team: insert(:team, teamset: teamset),
          upload: insert(:upload, user: student_user)
        )

      other_user = insert(:user)
      other_reg = insert(:reg, user: other_user, course: course)
      _other_sub =
        insert(:sub,
          assignment: assignment,
          reg: other_reg,
          team: insert(:team, teamset: teamset),
          upload: insert(:upload, user: other_user)
        )

      conn =
        get(student_conn, ~p"/api/v1/subs", %{assignment_id: assignment.id, all: "true"})

      response_ids =
        json_response(conn, 200)["data"] |> Enum.map(& &1["id"]) |> Enum.sort()

      expected_ids = [student_user_sub.id] |> Enum.sort()
      assert response_ids == expected_ids
    end

    test "returns empty list if no subs for assignment", %{
      conn: conn,
      course: course
    } do
      %{conn: conn, user: user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: user, course: course) # User needs to be registered in the course

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      assignment = insert(:assignment, bucket: bucket, teamset: teamset)

      conn = get(conn, ~p"/api/v1/subs", %{assignment_id: assignment.id})
      assert json_response(conn, 200)["data"] == []
    end

    test "returns empty list if user not registered in course", %{
      conn: conn,
      course: course
    } do
      %{conn: conn, user: _user} = logged_in_user_with_api_key(conn)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      assignment = insert(:assignment, bucket: bucket, teamset: teamset)

      conn = get(conn, ~p"/api/v1/subs", %{assignment_id: assignment.id})
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "show sub" do
    test "user can see their own sub", %{conn: conn} do
      %{conn: conn, user: user} = logged_in_user_with_api_key(conn)
      course = insert(:course)
      %{sub: sub} = create_sub_for_user(user, course)

      conn = get(conn, ~p"/api/v1/subs/#{sub.id}")
      assert json_response(conn, 200)["data"]["id"] == sub.id
    end

    test "user cannot see another user's sub", %{conn: conn} do
      %{conn: user_a_conn, user: _user_a} = logged_in_user_with_api_key(conn)
      user_b = insert(:user)
      course = insert(:course)
      %{sub: sub_b} = create_sub_for_user(user_b, course)

      conn = get(user_a_conn, ~p"/api/v1/subs/#{sub_b.id}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end

    test "staff user can see any sub in their course", %{conn: conn} do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      course = insert(:course)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      student_user = insert(:user)
      %{sub: student_sub} = create_sub_for_user(student_user, course)

      conn = get(staff_conn, ~p"/api/v1/subs/#{student_sub.id}")
      assert json_response(conn, 200)["data"]["id"] == student_sub.id
    end

    test "prof user can see any sub in their course", %{conn: conn} do
      %{conn: prof_conn, user: prof_user} = logged_in_user_with_api_key(conn)
      course = insert(:course)
      insert(:reg, user: prof_user, course: course, is_prof: true)

      student_user = insert(:user)
      %{sub: student_sub} = create_sub_for_user(student_user, course)

      conn = get(prof_conn, ~p"/api/v1/subs/#{student_sub.id}")
      assert json_response(conn, 200)["data"]["id"] == student_sub.id
    end

    test "staff/prof user cannot see a sub in a different course", %{conn: conn} do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      course_a = insert(:course)
      insert(:reg, user: staff_user, course: course_a, is_staff: true)

      course_b = insert(:course)
      student_user = insert(:user)
      %{sub: student_sub_in_course_b} = create_sub_for_user(student_user, course_b)

      conn = get(staff_conn, ~p"/api/v1/subs/#{student_sub_in_course_b.id}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end

    test "returns 404 for non-existent sub", %{conn: conn} do
      %{conn: conn} = logged_in_user_with_api_key(conn)
      # Use a large integer for a non-existent ID
      non_existent_id = 9_999_999_999

      conn = get(conn, ~p"/api/v1/subs/#{non_existent_id}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  describe "create sub" do
    # This setup now provides conn, user, assignment, etc.
    setup %{conn: initial_conn} do # Use a different name for the initial conn
      %{conn: authenticated_conn, sub: sub, user: user, assignment: assignment, reg: reg, team: team, upload: upload} = create_sub_for_test(%{conn: initial_conn})
      %{conn: authenticated_conn, sub: sub, user: user, assignment: assignment, reg: reg, team: team, upload: upload}
    end

    test "renders sub when data is valid", %{
      conn: conn, # Use the authenticated conn from setup
      assignment: assignment,
      reg: reg,
      team: team,
      upload: upload
    } do
      create_attrs =
        Map.merge(@create_attrs, %{
          assignment_id: assignment.id,
          reg_id: reg.id,
          team_id: team.id,
          upload_id: upload.id
        })

      # Corrected path
      conn = post(conn, ~p"/api/v1/subs", sub: create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      # Corrected path
      conn = get(conn, ~p"/api/v1/subs/#{id}")

      assert %{
               "id" => ^id,
               "active" => true,
               "hours_spent" => "120.5",
               "ignore_late_penalty" => true,
               "late_penalty" => "120.5",
               "note" => "some note",
               "score" => "120.5"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      # Corrected path
      conn = post(conn, ~p"/api/v1/subs", sub: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update sub" do
    # Use the common setup
    setup %{conn: initial_conn} do # Use a different name for the initial conn
      %{conn: authenticated_conn, sub: sub, user: user, assignment: assignment, reg: reg, team: team, upload: upload} = create_sub_for_test(%{conn: initial_conn})
      %{conn: authenticated_conn, sub: sub, user: user, assignment: assignment, reg: reg, team: team, upload: upload}
    end

    test "renders sub when data is valid", %{
      conn: conn, # Use the authenticated conn from setup
      sub: %Sub{id: id} = sub
    } do
      # Corrected path
      conn = put(conn, ~p"/api/v1/subs/#{sub}", sub: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      # Corrected path
      conn = get(conn, ~p"/api/v1/subs/#{id}")

      assert %{
               "id" => ^id,
               "active" => false,
               "hours_spent" => "456.7",
               "ignore_late_penalty" => false,
               "late_penalty" => "456.7",
               "note" => "some updated note",
               "score" => "456.7"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, sub: sub} do
      # Corrected path
      conn = put(conn, ~p"/api/v1/subs/#{sub}", sub: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  # Removed the "delete sub" describe block entirely as per user's instruction.
end
