defmodule InkfishWeb.ApiV1.Staff.GradeControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.Factory

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all grades for a sub", %{conn: conn} do
      stock = stock_course()
      sub = stock.sub
      grade = stock.grade
      grade_column = stock.grade_column
      staff = stock.staff

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn = get(conn, ~p"/api/v1/staff/grades?sub_id=#{sub.id}")
      response_data = json_response(conn, 200)["data"]
      assert [%{"id" => fetched_id}] = response_data
      assert fetched_id == grade.id

      [grade_data] = response_data
      assert grade_data["grade_column_id"] == grade_column.id
      assert grade_data["grade_column"]["id"] == grade_column.id
      assert grade_data["grade_column"]["name"] == grade_column.name
      assert grade_data["grade_column"]["kind"] == grade_column.kind
      assert grade_data["grade_column"]["points"] != nil
      assert grade_data["grade_column"]["base"] != nil
    end

    test "fails when sub_id is missing", %{conn: conn} do
      user = insert(:user)
      api_key = insert(:api_key, user: user)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn = get(conn, ~p"/api/v1/staff/grades")
      assert json_response(conn, 404)
    end
  end

  describe "create feedback grade" do
    test "creates feedback grade with line comments and recalculates score", %{
      conn: conn
    } do
      stock = stock_course()
      sub = stock.sub
      grade_column = stock.grade_column
      staff = stock.staff

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      line_comments = [
        %{
          "path" => "Ω_grading_extra.txt",
          "line" => 3,
          "points" => "-5.0",
          "text" => "Style issue"
        },
        %{
          "path" => "Ω_grading_extra.txt",
          "line" => 5,
          "points" => "-3.0",
          "text" => "Logic error"
        }
      ]

      create_attrs = %{
        sub_id: sub.id,
        grade_column_id: grade_column.id,
        line_comments: line_comments
      }

      conn =
        post(conn, ~p"/api/v1/staff/grades?sub_id=#{sub.id}",
          grade: create_attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("x-auth", api_key.key)

      conn = get(conn, ~p"/api/v1/staff/grades/#{id}")
      response_data = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "score" => "32.0"
             } = response_data

      assert response_data["grade_column_id"] == grade_column.id
      assert response_data["grade_column"]["id"] == grade_column.id
      assert response_data["grade_column"]["name"] == grade_column.name
      assert response_data["grade_column"]["kind"] == grade_column.kind

      assert [%{}, %{}] = response_data["line_comments"]
      [first_comment | _] = response_data["line_comments"]
      assert first_comment["user"]["id"]
      assert first_comment["user"]["name"]
    end

    test "rejects feedback grade with explicit score parameter", %{conn: conn} do
      stock = stock_course()
      sub = stock.sub
      grade_column = stock.grade_column
      staff = stock.staff

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      create_attrs = %{
        grade_column_id: grade_column.id,
        score: "35.0",
        line_comments: [
          %{
            "path" => "main.c",
            "line" => 10,
            "points" => "-5.0",
            "text" => "Style issue"
          }
        ]
      }

      conn =
        post(conn, ~p"/api/v1/staff/grades?sub_id=#{sub.id}",
          grade: create_attrs
        )

      assert %{"error" => error_message} = json_response(conn, 422)
      assert error_message =~ "Feedback grades are calculated automatically"
      assert error_message =~ "Score cannot be set directly"
    end

    test "rejects feedback grade with explicit score even without grade_column_id",
         %{
           conn: conn
         } do
      stock = stock_course()
      sub = stock.sub
      staff = stock.staff

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      create_attrs = %{
        score: "35.0",
        line_comments: [
          %{
            "path" => "main.c",
            "line" => 10,
            "points" => "-5.0",
            "text" => "Style issue"
          }
        ]
      }

      conn =
        post(conn, ~p"/api/v1/staff/grades?sub_id=#{sub.id}",
          grade: create_attrs
        )

      assert %{"error" => error_message} = json_response(conn, 422)
      assert error_message =~ "Feedback grades are calculated automatically"
      assert error_message =~ "Score cannot be set directly"
    end

    test "rejects feedback grade with empty text in line comment", %{
      conn: conn
    } do
      stock = stock_course()
      sub = stock.sub
      grade_column = stock.grade_column
      staff = stock.staff

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      line_comments = [
        %{
          "path" => "Ω_grading_extra.txt",
          "line" => 3,
          "points" => "-5.0",
          "text" => ""
        }
      ]

      create_attrs = %{
        sub_id: sub.id,
        grade_column_id: grade_column.id,
        line_comments: line_comments
      }

      conn =
        post(conn, ~p"/api/v1/staff/grades?sub_id=#{sub.id}",
          grade: create_attrs
        )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["text"]
      assert "Comment text cannot be empty" in errors["text"]
    end
  end

  describe "create number grade" do
    test "creates number grade with explicit score", %{conn: conn} do
      stock = stock_course()
      sub = stock.sub
      assignment = stock.assignment
      staff = stock.staff

      number_gcol =
        insert(:grade_column,
          kind: "number",
          name: "Participation",
          points: Decimal.new("10.0"),
          base: Decimal.new("0.0"),
          assignment: assignment
        )

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      create_attrs = %{
        grade_column_id: number_gcol.id,
        score: "8.5"
      }

      conn =
        post(conn, ~p"/api/v1/staff/grades?sub_id=#{sub.id}",
          grade: create_attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("x-auth", api_key.key)

      conn = get(conn, ~p"/api/v1/staff/grades/#{id}")
      response_data = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "score" => "8.5"
             } = response_data

      assert response_data["grade_column_id"] == number_gcol.id
      assert response_data["grade_column"]["id"] == number_gcol.id
      assert response_data["grade_column"]["name"] == number_gcol.name
      assert response_data["grade_column"]["kind"] == "number"
    end

    test "rejects number grade without score", %{conn: conn} do
      stock = stock_course()
      sub = stock.sub
      assignment = stock.assignment
      staff = stock.staff

      number_gcol =
        insert(:grade_column,
          kind: "number",
          name: "Participation",
          points: Decimal.new("10.0"),
          base: Decimal.new("0.0"),
          assignment: assignment
        )

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      create_attrs = %{
        grade_column_id: number_gcol.id
      }

      conn =
        post(conn, ~p"/api/v1/staff/grades?sub_id=#{sub.id}",
          grade: create_attrs
        )

      assert %{"error" => error_message} = json_response(conn, 422)
      assert error_message =~ "Number grades require a score value"
    end
  end

  describe "update grade with comments" do
    test "replaces only current user's comments and recalculates score", %{
      conn: conn
    } do
      stock = stock_course()
      sub = stock.sub
      grade_column = stock.grade_column
      staff = stock.staff
      student = stock.student

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      {:ok, grade} =
        Inkfish.Grades.create_grade(%{
          sub_id: sub.id,
          grade_column_id: grade_column.id
        })

      insert(:line_comment,
        grade: grade,
        user: student,
        path: "Ω_grading_extra.txt",
        line: 5,
        points: Decimal.new("-2.0"),
        text: "Existing comment by student"
      )

      existing_staff_comment =
        insert(:line_comment,
          user: staff,
          path: "Ω_grading_extra.txt",
          line: 4,
          points: Decimal.new("-3.0"),
          text: "Existing comment by staff"
        )

      new_line_comments = [
        %{
          "path" => "Ω_grading_extra.txt",
          "line" => 2,
          "points" => "-4.0",
          "text" => "New comment by staff"
        },
        %{
          "path" => "Ω_grading_extra.txt",
          "line" => 6,
          "points" => "-1.0",
          "text" => "Another new comment by staff"
        }
      ]

      update_attrs = %{
        grade_column_id: grade_column.id,
        line_comments: new_line_comments
      }

      conn =
        post(conn, ~p"/api/v1/staff/grades?sub_id=#{sub.id}",
          grade: update_attrs
        )

      response_data = json_response(conn, 201)["data"]

      assert %{
               "id" => fetched_id,
               "score" => "33.0"
             } = response_data

      assert fetched_id == grade.id

      assert response_data["grade_column_id"] == grade_column.id
      assert response_data["grade_column"]["id"] == grade_column.id
      assert response_data["grade_column"]["name"] == grade_column.name
      assert response_data["grade_column"]["kind"] == grade_column.kind

      assert length(response_data["line_comments"]) == 3

      student_comment =
        Enum.find(response_data["line_comments"], fn lc ->
          lc["user"]["id"] == student.id
        end)

      assert student_comment
      assert student_comment["text"] == "Existing comment by student"
      assert student_comment["points"] == "-2.0"

      old_staff_comment =
        Enum.find(response_data["line_comments"], fn lc ->
          lc["id"] == existing_staff_comment.id
        end)

      refute old_staff_comment

      new_staff_comments =
        Enum.filter(response_data["line_comments"], fn lc ->
          lc["user"]["id"] == staff.id and lc["id"] != existing_staff_comment.id
        end)

      assert length(new_staff_comments) == 2

      first_new_comment =
        Enum.find(response_data["line_comments"], fn lc ->
          lc["text"] == "New comment by staff"
        end)

      assert first_new_comment
      assert first_new_comment["points"] == "-4.0"

      second_new_comment =
        Enum.find(response_data["line_comments"], fn lc ->
          lc["text"] == "Another new comment by staff"
        end)

      assert second_new_comment
      assert second_new_comment["points"] == "-1.0"
    end
  end
end
