defmodule InkfishWeb.ApiV1.SubControllerTest do
  use InkfishWeb.ConnCase # Removed `use Inkfish.DataCase` as ConnCase already includes Factory

  import Inkfish.Factory

  alias Inkfish.Subs.Sub
  alias Inkfish.Repo

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

  # Helper to create an assignment and associated subs for testing index action
  defp create_assignment_with_subs(user, course, assignment_attrs \\ %{}) do
    bucket = insert(:bucket, course: course)
    # Create teamset explicitly linked to the course and pass it to assignment
    teamset = insert(:teamset, course: course)
    assignment = insert(:assignment, Map.merge(assignment_attrs, %{bucket: bucket, teamset: teamset}))

    # Create a reg for the user in this course
    reg = insert(:reg, user: user, course: course)
    team = insert(:team, teamset: assignment.teamset)
    insert(:team_member, team: team, reg: reg)

    # Create a sub for the user
    user_sub =
      insert(:sub,
        assignment: assignment,
        reg: reg,
        team: team,
        upload: insert(:upload, user: user)
      )

    # Create another user and their sub for the same assignment
    other_user = insert(:user)
    other_reg = insert(:reg, user: other_user, course: course)
    other_team = insert(:team, teamset: assignment.teamset)
    insert(:team_member, team: other_team, reg: other_reg)

    other_sub =
      insert(:sub,
        assignment: assignment,
        reg: other_reg,
        team: other_team,
        upload: insert(:upload, user: other_user)
      )

    %{
      assignment: assignment,
      user_sub: user_sub,
      other_sub: other_sub,
      user_reg: reg
    }
  end

  # Helper to create a sub for create/update/delete tests, ensuring it belongs to the authenticated user
  defp create_sub_for_test(%{conn: conn}) do
    %{conn: conn, user: user} = logged_in_user_with_api_key(conn)
    course = insert(:course)
    bucket = insert(:bucket, course: course)
    # Create teamset explicitly linked to the course and pass it to assignment
    teamset = insert(:teamset, course: course)
    assignment = insert(:assignment, bucket: bucket, teamset: teamset)

    reg = insert(:reg, user: user, course: course)
    team = insert(:team, teamset: assignment.teamset)
    insert(:team_member, team: team, reg: reg)
    upload = insert(:upload, user: user)

    sub =
      insert(:sub, assignment: assignment, reg: reg, team: team, upload: upload)

    %{
      conn: conn,
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
      # Corrected path
      conn = get(conn, ~p"/api/v1/subs")
      assert json_response(conn, 400)["error"] == "assignment_id is required"
    end

    test "lists only current user's subs for a given assignment", %{
      conn: conn,
      course: course
    } do
      # Setup user and API key
      %{conn: conn, user: user} = logged_in_user_with_api_key(conn)

      # Setup assignment and subs
      %{assignment: assignment, user_sub: user_sub, other_sub: _other_sub} =
        create_assignment_with_subs(user, course)

      # Corrected path
      conn = get(conn, ~p"/api/v1/subs", %{assignment_id: assignment.id})

      assert json_response(conn, 200)["data"]
             |> Enum.map(& &1["id"])
             |> Enum.sort() == [user_sub.id] |> Enum.sort()
    end

    test "staff/prof user can list all subs for a given assignment with 'all' parameter",
         %{conn: conn, course: course} do
      # Setup staff user and API key
      %{conn: conn, user: staff_user} = logged_in_user_with_api_key(conn)
      # Make staff_user a staff member in the course
      insert(:reg, user: staff_user, course: course, is_staff: true)

      # Setup assignment and subs
      %{assignment: assignment, user_sub: staff_user_sub, other_sub: other_sub} =
        create_assignment_with_subs(staff_user, course)

      # Corrected path
      conn =
        get(conn, ~p"/api/v1/subs", %{assignment_id: assignment.id, all: "true"})

      response_ids =
        json_response(conn, 200)["data"] |> Enum.map(& &1["id"]) |> Enum.sort()

      expected_ids = [staff_user_sub.id, other_sub.id] |> Enum.sort()
      assert response_ids == expected_ids
    end

    test "non-staff/prof user cannot list all subs for a given assignment with 'all' parameter",
         %{conn: conn, course: course} do
      # Setup student user and API key
      %{conn: conn, user: student_user} = logged_in_user_with_api_key(conn)
      # Make student_user a student member in the course
      insert(:reg, user: student_user, course: course, is_student: true)

      # Setup assignment and subs
      %{
        assignment: assignment,
        user_sub: student_user_sub,
        other_sub: _other_sub
      } = create_assignment_with_subs(student_user, course)

      # Corrected path
      conn =
        get(conn, ~p"/api/v1/subs", %{assignment_id: assignment.id, all: "true"})

      # The user should still only see their own sub, even if 'all' is specified
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
      bucket = insert(:bucket, course: course)
      assignment = insert(:assignment, bucket: bucket)
      # User needs to be registered in the course
      insert(:reg, user: user, course: course)

      # Corrected path
      conn = get(conn, ~p"/api/v1/subs", %{assignment_id: assignment.id})
      assert json_response(conn, 200)["data"] == []
    end

    test "returns empty list if user not registered in course", %{
      conn: conn,
      course: course
    } do
      %{conn: conn, user: _user} = logged_in_user_with_api_key(conn)
      bucket = insert(:bucket, course: course)
      assignment = insert(:assignment, bucket: bucket)
      # User is NOT registered in the course associated with the assignment

      # Corrected path
      conn = get(conn, ~p"/api/v1/subs", %{assignment_id: assignment.id})
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create sub" do
    # This setup now provides conn, user, assignment, etc.
    setup [:create_sub_for_test]

    test "renders sub when data is valid", %{
      conn: conn,
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
    setup [:create_sub_for_test]

    test "renders sub when data is valid", %{
      conn: conn,
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

  describe "delete sub" do
    # Use the common setup
    setup [:create_sub_for_test]

    test "deletes chosen sub", %{conn: conn, sub: sub} do
      # Corrected path
      conn = delete(conn, ~p"/api/v1/subs/#{sub}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        # Corrected path
        get(conn, ~p"/api/v1/subs/#{sub}")
      end
    end
  end
end
