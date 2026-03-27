defmodule InkfishWeb.ApiV1.Staff.TeamsetControllerTest do
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

  describe "create teamset" do
    test "staff user can create a teamset", %{conn: conn, course: course} do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      teamset_params = %{
        "name" => "Team Project"
      }

      conn =
        post(staff_conn, ~p"/api/v1/staff/courses/#{course.id}/teamsets", %{
          teamset: teamset_params
        })

      response = json_response(conn, 201)

      assert %{"data" => %{"id" => _, "name" => "Team Project"}} = response
    end

    test "prof user can create a teamset", %{conn: conn, course: course} do
      %{conn: prof_conn, user: prof_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: prof_user, course: course, is_prof: true)

      teamset_params = %{
        "name" => "Team Project"
      }

      conn =
        post(prof_conn, ~p"/api/v1/staff/courses/#{course.id}/teamsets", %{
          teamset: teamset_params
        })

      response = json_response(conn, 201)

      assert %{"data" => %{"name" => "Team Project"}} = response
    end

    test "non-staff user cannot create a teamset", %{conn: conn, course: course} do
      %{conn: student_conn, user: student_user} =
        logged_in_user_with_api_key(conn)

      insert(:reg, user: student_user, course: course, is_student: true)

      teamset_params = %{
        "name" => "Team Project"
      }

      conn =
        post(student_conn, ~p"/api/v1/staff/courses/#{course.id}/teamsets", %{
          teamset: teamset_params
        })

      assert json_response(conn, 403)["error"] == "Access denied"
    end

    test "user not registered in course cannot create", %{
      conn: conn,
      course: course
    } do
      %{conn: user_conn, user: _user} = logged_in_user_with_api_key(conn)

      teamset_params = %{
        "name" => "Team Project"
      }

      conn =
        post(user_conn, ~p"/api/v1/staff/courses/#{course.id}/teamsets", %{
          teamset: teamset_params
        })

      assert json_response(conn, 403)["error"] == "Registration required"
    end

    test "creates teamset with valid params", %{conn: conn, course: course} do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      teamset_params = %{
        "name" => "New Teamset"
      }

      conn =
        post(staff_conn, ~p"/api/v1/staff/courses/#{course.id}/teamsets", %{
          teamset: teamset_params
        })

      response = json_response(conn, 201)

      assert %{"data" => %{"name" => "New Teamset", "course_id" => course_id}} =
               response

      assert course_id == course.id
    end

    test "missing required fields returns 422", %{conn: conn, course: course} do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      teamset_params = %{}

      conn =
        post(staff_conn, ~p"/api/v1/staff/courses/#{course.id}/teamsets", %{
          teamset: teamset_params
        })

      assert json_response(conn, 422)
    end

    test "requires valid API key", %{conn: conn, course: course} do
      conn = put_req_header(conn, "x-auth", "invalid-key")

      teamset_params = %{
        "name" => "Team Project"
      }

      conn =
        post(conn, ~p"/api/v1/staff/courses/#{course.id}/teamsets", %{
          teamset: teamset_params
        })

      assert json_response(conn, 403)
    end
  end
end
