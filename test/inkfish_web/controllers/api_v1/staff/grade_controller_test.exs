defmodule InkfishWeb.ApiV1.Staff.GradeControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.Factory

  alias Inkfish.Grades.Grade

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all grades for a sub", %{conn: conn} do
      # Need to create a complete test setup with a submission and grade
      stock = stock_course()
      sub = stock.sub
      grade = stock.grade
      
      conn = get(conn, ~p"/api/v1/staff/grades?sub_id=#{sub.id}")
      assert [%{"id" => fetched_id}] = json_response(conn, 200)["data"]
      assert fetched_id == grade.id
    end

    test "fails when sub_id is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/staff/grades")
      assert json_response(conn, 400)
    end
  end

  describe "create grade" do
    test "creates grade with line comments and recalculates score", %{conn: conn} do
      # Create test data
      stock = stock_course()
      sub = stock.sub
      grade_column = stock.grade_column
      staff = stock.staff
      
      # Create API key for the staff user
      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)
      
      # Line comments to add
      line_comments = [
        %{
          "path" => "main.c",
          "line" => 10,
          "points" => "-5.0",
          "text" => "Style issue"
        },
        %{
          "path" => "main.c", 
          "line" => 15,
          "points" => "-3.0",
          "text" => "Logic error"
        }
      ]
      
      # Base score is 40.0, comments deduct 8.0, so final should be 32.0
      create_attrs = %{
        sub_id: sub.id,
        grade_column_id: grade_column.id,
        line_comments: line_comments
      }
      
      conn = post(conn, ~p"/api/v1/staff/grades", grade: create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]
      
      # Check that grade was created with correct score
      conn = get(conn, ~p"/api/v1/staff/grades/#{id}")
      response_data = json_response(conn, 200)["data"]
      
      assert %{
               "id" => ^id,
               "score" => "32.0"
             } = response_data
      
      # Check that line comments are included with user data
      assert [%{}, %{}] = response_data["line_comments"]
      [first_comment | _] = response_data["line_comments"]
      assert first_comment["user"]["id"]
      assert first_comment["user"]["name"]
    end
  end

  describe "update grade with comments" do
    test "replaces only current user's comments and recalculates score", %{conn: conn} do
      # Create test data
      stock = stock_course()
      sub = stock.sub
      grade_column = stock.grade_column
      staff = stock.staff
      student = stock.student
      
      # Create API key for the staff user
      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)
      
      # Create an existing grade
      {:ok, grade} = Inkfish.Grades.create_grade(%{
        sub_id: sub.id,
        grade_column_id: grade_column.id
      })
      
      # Add a comment by another user (the student)
      insert(:line_comment, 
        grade: grade, 
        user: student,
        path: "main.c",
        line: 5,
        points: Decimal.new("-2.0"),
        text: "Existing comment by student"
      )
      
      # Add comments by the staff user that will be replaced
      existing_staff_comment = insert(:line_comment,
        grade: grade,
        user: staff,
        path: "main.c",
        line: 10,
        points: Decimal.new("-3.0"),
        text: "Existing comment by staff"
      )
      
      # New comments to replace the staff user's comments
      new_line_comments = [
        %{
          "path" => "main.c",
          "line" => 15,
          "points" => "-4.0",
          "text" => "New comment by staff"
        },
        %{
          "path" => "helper.c",
          "line" => 20,
          "points" => "-1.0",
          "text" => "Another new comment by staff"
        }
      ]
      
      # Base score is 40.0
      # Existing student comment: -2.0
      # Existing staff comment (to be replaced): -3.0
      # New staff comments: -4.0 + -1.0 = -5.0
      # Expected final score: 40.0 + (-2.0) + (-5.0) = 33.0
      
      update_attrs = %{
        sub_id: sub.id,
        grade_column_id: grade_column.id,
        line_comments: new_line_comments
      }
      
      conn = post(conn, ~p"/api/v1/staff/grades", grade: update_attrs)
      response_data = json_response(conn, 201)["data"]
      
      # Check that grade was updated with correct score
      assert %{
               "id" => fetched_id,
               "score" => "33.0"
             } = response_data
      assert fetched_id == grade.id
      
      # Check that line comments are included
      assert length(response_data["line_comments"]) == 3
      
      # Verify the student's comment is still there
      student_comment = Enum.find(response_data["line_comments"], fn lc -> 
        lc["user"]["id"] == student.id
      end)
      assert student_comment
      assert student_comment["text"] == "Existing comment by student"
      assert student_comment["points"] == "-2.0"
      
      # Verify the old staff comment is gone
      old_staff_comment = Enum.find(response_data["line_comments"], fn lc -> 
        lc["id"] == existing_staff_comment.id
      end)
      refute old_staff_comment
      
      # Verify the new staff comments are there
      new_staff_comments = Enum.filter(response_data["line_comments"], fn lc -> 
        lc["user"]["id"] == staff.id and lc["id"] != existing_staff_comment.id
      end)
      assert length(new_staff_comments) == 2
      
      # Check that each new comment has the correct data
      first_new_comment = Enum.find(response_data["line_comments"], fn lc -> 
        lc["text"] == "New comment by staff"
      end)
      assert first_new_comment
      assert first_new_comment["points"] == "-4.0"
      
      second_new_comment = Enum.find(response_data["line_comments"], fn lc -> 
        lc["text"] == "Another new comment by staff"
      end)
      assert second_new_comment
      assert second_new_comment["points"] == "-1.0"
    end
  end

  describe "delete grade" do
    test "deletes chosen grade", %{conn: conn} do
      stock = stock_course()
      grade = stock.grade
      
      conn = delete(conn, ~p"/api/v1/staff/grades/#{grade}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/v1/staff/grades/#{grade}")
      end
    end
  end
end
