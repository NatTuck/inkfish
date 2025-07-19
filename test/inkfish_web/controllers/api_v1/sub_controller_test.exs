defmodule InkfishWeb.ApiV1.SubControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.Factory

  @create_attrs %{
    # These are the fields that Sub.changeset actually casts
    hours_spent: "1.0",
    note: "some note"
  }
  @invalid_attrs %{
    # hours_spent is required
    hours_spent: nil
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

      assert json_response(conn, 404)
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

    test "returns empty list if no subs for assignment", %{
      conn: conn,
      course: course
    } do
      %{conn: conn, user: user} = logged_in_user_with_api_key(conn)
      # User needs to be registered in the course
      insert(:reg, user: user, course: course)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      assignment = insert(:assignment, bucket: bucket, teamset: teamset)

      conn = get(conn, ~p"/api/v1/subs", %{assignment_id: assignment.id})
      assert json_response(conn, 200)["data"] == []
    end

    test "permission denied if user not registered in course", %{
      conn: conn,
      course: course
    } do
      %{conn: conn, user: _user} = logged_in_user_with_api_key(conn)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      assignment = insert(:assignment, bucket: bucket, teamset: teamset)

      conn = get(conn, ~p"/api/v1/subs", %{assignment_id: assignment.id})
      assert json_response(conn, 403)
    end
  end

  describe "create sub" do
    # This setup now provides conn, user, assignment, etc.
    setup %{conn: initial_conn} do
      %{conn: authenticated_conn, user: user, api_key: api_key} =
        logged_in_user_with_api_key(initial_conn)

      course = insert(:course)
      reg = insert(:reg, user: user, course: course)

      assignment =
        insert(:assignment,
          bucket: insert(:bucket, course: course),
          teamset: insert(:teamset, course: course)
        )

      # Create a team for the reg and assignment
      team = insert(:team, teamset: assignment.teamset)
      insert(:team_member, team: team, reg: reg)

      %{
        conn: authenticated_conn,
        user: user,
        reg: reg,
        assignment: assignment,
        api_key: api_key
      }
    end

    @tag :tmp_dir
    test "renders sub when data is valid", %{
      conn: conn,
      assignment: assignment,
      api_key: api_key,
      tmp_dir: tmp_dir
    } do
      path = Path.join(tmp_dir, "upload.txt")
      File.write!(path, "some content")

      upload = %Plug.Upload{
        path: path,
        filename: "submission.txt",
        content_type: "text/plain"
      }

      create_params =
        Map.merge(@create_attrs, %{
          "assignment_id" => Integer.to_string(assignment.id),
          "upload" => upload
        })

      # Perform the POST request
      post_conn = post(conn, ~p"/api/v1/subs", %{sub: create_params})
      assert %{"id" => id} = json_response(post_conn, 201)["data"]

      # For the subsequent GET request, build a fresh authenticated conn
      get_conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("x-auth", api_key.key)

      # Perform the GET request
      get_conn = get(get_conn, ~p"/api/v1/subs/#{id}")

      assert %{
               "id" => ^id,
               "active" => true,
               "hours_spent" => "1.0",
               "ignore_late_penalty" => false,
               "late_penalty" => nil,
               "note" => "some note",
               "score" => nil
             } = json_response(get_conn, 200)["data"]
    end

    @tag :tmp_dir
    test "renders errors when data is invalid", %{
      conn: conn,
      assignment: assignment,
      tmp_dir: tmp_dir
    } do
      path = Path.join(tmp_dir, "upload.txt")
      File.write!(path, "some content")

      upload = %Plug.Upload{
        path: path,
        filename: "submission.txt",
        content_type: "text/plain"
      }

      invalid_params =
        Map.merge(@invalid_attrs, %{
          "assignment_id" => Integer.to_string(assignment.id),
          "upload" => upload
        })

      conn = post(conn, ~p"/api/v1/subs", %{sub: invalid_params})
      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag :tmp_dir
    test "renders 400 if assignment_id is not found", %{
      conn: conn,
      tmp_dir: tmp_dir
    } do
      path = Path.join(tmp_dir, "upload.txt")
      File.write!(path, "some content")

      upload = %Plug.Upload{
        path: path,
        filename: "submission.txt",
        content_type: "text/plain"
      }

      create_params = %{
        "assignment_id" => "999999999",
        "upload" => upload
      }

      conn = post(conn, ~p"/api/v1/subs", %{sub: create_params})
      assert json_response(conn, 400)
    end

    test "renders error when upload parameter is missing", %{
      conn: conn,
      assignment: assignment
    } do
      create_params = %{
        "assignment_id" => Integer.to_string(assignment.id)
      }

      conn = post(conn, ~p"/api/v1/subs", %{sub: create_params})
      assert response(conn, 400)
      assert json_response(conn, 400)["error"] == "upload is required"
    end
  end

  # This controller doesn't have update or delete actions.
end
