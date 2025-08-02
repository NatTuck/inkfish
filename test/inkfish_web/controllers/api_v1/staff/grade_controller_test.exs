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
      
      conn = get(conn, ~p"/api/api_v1/staff/grades?sub_id=#{sub.id}")
      assert [%{"id" => ^id}] = json_response(conn, 200)["data"]
      assert id == grade.id
    end

    test "fails when sub_id is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/api_v1/staff/grades")
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
      conn = put_req_header(conn, "authorization", "Bearer #{api_key.key}")
      
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
      
      conn = post(conn, ~p"/api/api_v1/staff/grades", grade: create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]
      
      # Check that grade was created with correct score
      conn = get(conn, ~p"/api/api_v1/staff/grades/#{id}")
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

  describe "delete grade" do
    test "deletes chosen grade", %{conn: conn} do
      stock = stock_course()
      grade = stock.grade
      
      conn = delete(conn, ~p"/api/api_v1/staff/grades/#{grade}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/api_v1/staff/grades/#{grade}")
      end
    end
  end
end
