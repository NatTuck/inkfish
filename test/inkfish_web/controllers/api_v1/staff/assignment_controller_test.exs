defmodule InkfishWeb.ApiV1.Staff.AssignmentControllerTest do
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

  # Helper to create an assignment in a given course
  defp create_assignment(course, assignment_attrs \\ %{}) do
    bucket = insert(:bucket, course: course)
    teamset = insert(:teamset, course: course)

    assignment =
      insert(
        :assignment,
        Map.merge(assignment_attrs, %{bucket: bucket, teamset: teamset})
      )

    %{
      assignment: assignment,
      bucket: bucket,
      teamset: teamset
    }
  end

  describe "show assignment" do
    test "staff user can see assignment in their course", %{
      conn: conn,
      course: course
    } do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      %{assignment: assignment} = create_assignment(course)

      conn = get(staff_conn, ~p"/api/v1/staff/assignments/#{assignment.id}")
      response = json_response(conn, 200)

      assert %{"data" => %{"id" => assignment_id}} = response
      assert assignment_id == assignment.id
    end

    test "prof user can see assignment in their course", %{
      conn: conn,
      course: course
    } do
      %{conn: prof_conn, user: prof_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: prof_user, course: course, is_prof: true)

      %{assignment: assignment} = create_assignment(course)

      conn = get(prof_conn, ~p"/api/v1/staff/assignments/#{assignment.id}")
      response = json_response(conn, 200)

      assert %{"data" => %{"id" => assignment_id}} = response
      assert assignment_id == assignment.id
    end

    test "staff/prof user cannot see assignment in a different course", %{
      conn: conn
    } do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      course_a = insert(:course)
      insert(:reg, user: staff_user, course: course_a, is_staff: true)

      course_b = insert(:course)
      %{assignment: assignment_in_course_b} = create_assignment(course_b)

      conn =
        get(
          staff_conn,
          ~p"/api/v1/staff/assignments/#{assignment_in_course_b.id}"
        )

      assert json_response(conn, 403)
    end

    test "non-staff user cannot see assignment", %{
      conn: conn,
      course: course
    } do
      %{conn: student_conn, user: student_user} =
        logged_in_user_with_api_key(conn)

      insert(:reg, user: student_user, course: course, is_student: true)

      %{assignment: assignment} = create_assignment(course)

      conn = get(student_conn, ~p"/api/v1/staff/assignments/#{assignment.id}")
      assert json_response(conn, 403)["error"] == "Access denied"
    end

    test "returns 404 for non-existent assignment", %{
      conn: conn,
      course: course
    } do
      %{conn: conn, user: user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: user, course: course, is_staff: true)
      # Use a large integer for a non-existent ID
      non_existent_id = 9_999_999_999

      conn = get(conn, ~p"/api/v1/staff/assignments/#{non_existent_id}")
      assert json_response(conn, 404)
    end

    test "requires valid API key", %{conn: conn, course: course} do
      conn = put_req_header(conn, "x-auth", "invalid-key")
      %{assignment: assignment} = create_assignment(course)

      conn = get(conn, ~p"/api/v1/staff/assignments/#{assignment.id}")
      assert json_response(conn, 403)
    end

    test "returns assignment with all related data", %{
      conn: conn,
      course: course
    } do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)

      _staff_reg =
        insert(:reg, user: staff_user, course: course, is_staff: true)

      %{assignment: assignment} =
        create_assignment(course, %{
          name: "Test Assignment",
          desc: "Test Description"
        })

      # Add grade columns
      gcol1 =
        insert(:grade_column,
          assignment: assignment,
          name: "Problem 1",
          points: "10"
        )

      gcol2 =
        insert(:grade_column,
          assignment: assignment,
          name: "Problem 2",
          points: "15"
        )

      conn = get(staff_conn, ~p"/api/v1/staff/assignments/#{assignment.id}")
      response = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => assignment_id,
                 "name" => "Test Assignment",
                 "desc" => "Test Description",
                 "bucket" => %{"id" => _},
                 "grade_columns" => [
                   %{"id" => gcol1_id, "name" => "Problem 1", "points" => "10"},
                   %{"id" => gcol2_id, "name" => "Problem 2", "points" => "15"}
                 ]
               }
             } = response

      assert assignment_id == assignment.id
      assert gcol1_id == gcol1.id
      assert gcol2_id == gcol2.id
    end
  end

  describe "create assignment" do
    test "staff user can create assignment with explicit teamset_id", %{
      conn: conn,
      course: course
    } do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)

      due_date = Inkfish.LocalTime.in_days(7)

      assignment_params = %{
        "name" => "Homework 1",
        "desc" => "First homework assignment",
        "due" => due_date,
        "weight" => "1.0",
        "bucket_id" => bucket.id,
        "teamset_id" => teamset.id
      }

      conn =
        post(
          staff_conn,
          ~p"/api/v1/staff/assignments?course_id=#{course.id}",
          %{
            assignment: assignment_params
          }
        )

      response = json_response(conn, 201)

      assert %{"data" => %{"id" => _, "name" => "Homework 1"}} = response
    end

    test "staff user can create assignment without teamset_id uses solo_teamset",
         %{
           conn: conn
         } do
      course = insert(:course)
      solo_teamset = Inkfish.Teams.create_solo_teamset!(course)
      course = Inkfish.Courses.get_course!(course.id)

      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      bucket = insert(:bucket, course: course)
      due_date = Inkfish.LocalTime.in_days(7)

      assignment_params = %{
        "name" => "Homework 1",
        "desc" => "First homework",
        "due" => due_date,
        "weight" => "1.0",
        "bucket_id" => bucket.id
      }

      conn =
        post(
          staff_conn,
          ~p"/api/v1/staff/assignments?course_id=#{course.id}",
          %{
            assignment: assignment_params
          }
        )

      response = json_response(conn, 201)

      assert %{"data" => %{"id" => _, "teamset" => %{"id" => teamset_id}}} =
               response

      assert teamset_id == solo_teamset.id
    end

    test "prof user can create assignment", %{conn: conn, course: course} do
      %{conn: prof_conn, user: prof_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: prof_user, course: course, is_prof: true)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      due_date = Inkfish.LocalTime.in_days(7)

      assignment_params = %{
        "name" => "Homework 1",
        "desc" => "First homework",
        "due" => due_date,
        "weight" => "1.0",
        "bucket_id" => bucket.id,
        "teamset_id" => teamset.id
      }

      conn =
        post(prof_conn, ~p"/api/v1/staff/assignments?course_id=#{course.id}", %{
          assignment: assignment_params
        })

      response = json_response(conn, 201)

      assert %{"data" => %{"name" => "Homework 1"}} = response
    end

    test "non-staff user cannot create assignment", %{
      conn: conn,
      course: course
    } do
      %{conn: student_conn, user: student_user} =
        logged_in_user_with_api_key(conn)

      insert(:reg, user: student_user, course: course, is_student: true)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      due_date = Inkfish.LocalTime.in_days(7)

      assignment_params = %{
        "name" => "Homework 1",
        "desc" => "First homework",
        "due" => due_date,
        "weight" => "1.0",
        "bucket_id" => bucket.id,
        "teamset_id" => teamset.id
      }

      conn =
        post(
          student_conn,
          ~p"/api/v1/staff/assignments?course_id=#{course.id}",
          %{
            assignment: assignment_params
          }
        )

      assert json_response(conn, 403)["error"] == "Access denied"
    end

    test "user not registered in course cannot create", %{
      conn: conn,
      course: course
    } do
      %{conn: user_conn, user: _user} = logged_in_user_with_api_key(conn)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      due_date = Inkfish.LocalTime.in_days(7)

      assignment_params = %{
        "name" => "Homework 1",
        "desc" => "First homework",
        "due" => due_date,
        "weight" => "1.0",
        "bucket_id" => bucket.id,
        "teamset_id" => teamset.id
      }

      conn =
        post(user_conn, ~p"/api/v1/staff/assignments?course_id=#{course.id}", %{
          assignment: assignment_params
        })

      assert json_response(conn, 403)["error"] == "Registration required"
    end

    test "creates assignment with valid params", %{conn: conn, course: course} do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      due_date = Inkfish.LocalTime.in_days(7)

      assignment_params = %{
        "name" => "Test Assignment",
        "desc" => "Test description",
        "due" => due_date,
        "weight" => "0.5",
        "bucket_id" => bucket.id,
        "teamset_id" => teamset.id
      }

      conn =
        post(
          staff_conn,
          ~p"/api/v1/staff/assignments?course_id=#{course.id}",
          %{
            assignment: assignment_params
          }
        )

      response = json_response(conn, 201)

      assert %{
               "data" => %{
                 "name" => "Test Assignment",
                 "desc" => "Test description",
                 "bucket" => %{"id" => bucket_id},
                 "teamset" => %{"id" => teamset_id}
               }
             } = response

      assert bucket_id == bucket.id
      assert teamset_id == teamset.id
    end

    test "missing required fields returns 422", %{conn: conn, course: course} do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      bucket = insert(:bucket, course: course)
      _solo_teamset = Inkfish.Teams.create_solo_teamset!(course)

      assignment_params = %{
        "bucket_id" => bucket.id
      }

      conn =
        post(
          staff_conn,
          ~p"/api/v1/staff/assignments?course_id=#{course.id}",
          %{
            assignment: assignment_params
          }
        )

      assert json_response(conn, 422)
    end

    test "invalid bucket_id returns 404", %{conn: conn} do
      %{conn: staff_conn, user: staff_user} = logged_in_user_with_api_key(conn)
      course = insert(:course)
      insert(:reg, user: staff_user, course: course, is_staff: true)

      teamset = insert(:teamset, course: course)
      due_date = Inkfish.LocalTime.in_days(7)

      assignment_params = %{
        "name" => "Homework 1",
        "desc" => "First homework",
        "due" => due_date,
        "weight" => "1.0",
        "bucket_id" => 9_999_999_999,
        "teamset_id" => teamset.id
      }

      conn =
        post(
          staff_conn,
          ~p"/api/v1/staff/assignments?course_id=#{course.id}",
          %{
            assignment: assignment_params
          }
        )

      assert json_response(conn, 404)
    end

    test "requires valid API key", %{conn: conn, course: course} do
      conn = put_req_header(conn, "x-auth", "invalid-key")

      bucket = insert(:bucket, course: course)
      teamset = insert(:teamset, course: course)
      due_date = Inkfish.LocalTime.in_days(7)

      assignment_params = %{
        "name" => "Homework 1",
        "desc" => "First homework",
        "due" => due_date,
        "weight" => "1.0",
        "bucket_id" => bucket.id,
        "teamset_id" => teamset.id
      }

      conn =
        post(conn, ~p"/api/v1/staff/assignments?course_id=#{course.id}", %{
          assignment: assignment_params
        })

      assert json_response(conn, 403)
    end
  end
end
