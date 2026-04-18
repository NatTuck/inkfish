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
      staff = stock.staff

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn = get(conn, ~p"/api/v1/staff/grades?sub_id=#{sub.id}")
      response_data = json_response(conn, 200)["data"]

      # Should include both feedback grade (unconfirmed) and number grade (confirmed)
      assert length(response_data) == 2

      # Find the feedback grade
      feedback_grade =
        Enum.find(response_data, &(&1["grade_column"]["kind"] == "feedback"))

      assert feedback_grade["id"] == grade.id
      assert feedback_grade["confirmed"] == false
      assert feedback_grade["score"] == nil

      # Find the confirmed number grade
      number_grade =
        Enum.find(response_data, &(&1["grade_column"]["kind"] == "number"))

      assert number_grade["confirmed"] == true
      assert number_grade["score"] != nil
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
               "confirmed" => false,
               "score" => nil,
               "preview_score" => "32.0"
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

  describe "line comments CRUD on unconfirmed grade" do
    test "creates line comment and returns comment with grade preview", %{
      conn: conn
    } do
      stock = stock_course()
      grade = stock.grade
      staff = stock.staff

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      comment_attrs = %{
        "path" => "Ω_grading_extra.txt",
        "line" => 5,
        "points" => "-3.0",
        "text" => "Logic error"
      }

      conn =
        post(conn, ~p"/api/v1/staff/grades/#{grade.id}/line_comments",
          line_comment: comment_attrs
        )

      assert %{
               "id" => _comment_id,
               "path" => "Ω_grading_extra.txt",
               "line" => 5,
               "points" => "-3.0",
               "text" => "Logic error",
               "grade" => grade_data
             } = json_response(conn, 201)["data"]

      # Verify grade data is included with preview_score
      assert grade_data["id"] == grade.id
      assert grade_data["confirmed"] == false
      assert grade_data["score"] == nil
      assert grade_data["preview_score"] == "37.0"
    end

    test "updates line comment and returns updated comment with grade preview",
         %{conn: conn} do
      stock = stock_course()
      grade = stock.grade
      staff = stock.staff

      # Create a comment first
      {:ok, comment} =
        Inkfish.LineComments.create_line_comment(
          %{
            grade_id: grade.id,
            user_id: staff.id,
            path: "Ω_grading_extra.txt",
            line: 3,
            points: Decimal.new("-5.0"),
            text: "Original"
          },
          ["Ω_grading_extra.txt"]
        )

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn =
        patch(conn, ~p"/api/v1/staff/line_comments/#{comment.id}",
          line_comment: %{"text" => "Updated text", "points" => "-2.0"}
        )

      assert %{
               "id" => comment_id,
               "text" => "Updated text",
               "points" => "-2.0",
               "grade" => grade_data
             } = json_response(conn, 200)["data"]

      assert comment_id == comment.id

      # preview_score should be recalculated
      assert grade_data["preview_score"] == "38.0"
    end

    test "deletes line comment and returns grade with updated preview", %{
      conn: conn
    } do
      stock = stock_course()
      grade = stock.grade
      staff = stock.staff

      # Create a comment first
      {:ok, comment} =
        Inkfish.LineComments.create_line_comment(
          %{
            grade_id: grade.id,
            user_id: staff.id,
            path: "Ω_grading_extra.txt",
            line: 3,
            points: Decimal.new("-5.0"),
            text: "To delete"
          },
          ["Ω_grading_extra.txt"]
        )

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn = delete(conn, ~p"/api/v1/staff/line_comments/#{comment.id}")

      assert %{"grade" => grade_data} = json_response(conn, 200)["data"]

      # preview_score should be recalculated (back to base)
      assert grade_data["preview_score"] == "40.0"
    end

    test "line comments are ordered by path then line number", %{conn: conn} do
      stock = stock_course()
      grade = stock.grade
      staff = stock.staff

      # Create comments out of order
      insert(:line_comment,
        grade: grade,
        user: staff,
        path: "b_file.c",
        line: 10,
        points: Decimal.new("-1.0"),
        text: "B file line 10"
      )

      insert(:line_comment,
        grade: grade,
        user: staff,
        path: "a_file.c",
        line: 20,
        points: Decimal.new("-2.0"),
        text: "A file line 20"
      )

      insert(:line_comment,
        grade: grade,
        user: staff,
        path: "a_file.c",
        line: 5,
        points: Decimal.new("-3.0"),
        text: "A file line 5"
      )

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn = get(conn, ~p"/api/v1/staff/grades/#{grade.id}")
      response_data = json_response(conn, 200)["data"]

      comments = response_data["line_comments"]
      assert length(comments) == 3

      # Should be ordered: a_file.c:5, a_file.c:20, b_file.c:10
      assert Enum.at(comments, 0)["path"] == "a_file.c"
      assert Enum.at(comments, 0)["line"] == 5

      assert Enum.at(comments, 1)["path"] == "a_file.c"
      assert Enum.at(comments, 1)["line"] == 20

      assert Enum.at(comments, 2)["path"] == "b_file.c"
      assert Enum.at(comments, 2)["line"] == 10
    end
  end

  describe "line comments on confirmed grade" do
    test "returns 403 when creating comment on confirmed grade", %{conn: conn} do
      stock = stock_course()
      confirmed_grade = stock.confirmed_grade
      staff = stock.staff

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn =
        post(conn, ~p"/api/v1/staff/grades/#{confirmed_grade.id}/line_comments",
          line_comment: %{
            "path" => "Ω_grading_extra.txt",
            "line" => 3,
            "points" => "-5.0",
            "text" => "Should fail"
          }
        )

      assert json_response(conn, 403)
      assert json_response(conn, 403)["error"] == "grade_already_confirmed"
    end

    test "returns 403 when updating comment on confirmed grade", %{conn: conn} do
      stock = stock_course()
      confirmed_grade = stock.confirmed_grade
      staff = stock.staff

      # Create a comment on the confirmed grade (bypassing restriction for test setup)
      {:ok, comment} =
        Inkfish.Repo.insert(%Inkfish.LineComments.LineComment{
          grade_id: confirmed_grade.id,
          user_id: staff.id,
          path: "Ω_grading_extra.txt",
          line: 3,
          points: Decimal.new("-5.0"),
          text: "Original"
        })

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn =
        patch(conn, ~p"/api/v1/staff/line_comments/#{comment.id}",
          line_comment: %{"text" => "Updated"}
        )

      assert json_response(conn, 403)
      assert json_response(conn, 403)["error"] == "grade_already_confirmed"
    end

    test "returns 403 when deleting comment on confirmed grade", %{conn: conn} do
      stock = stock_course()
      confirmed_grade = stock.confirmed_grade
      staff = stock.staff

      # Create a comment on the confirmed grade (bypassing restriction for test setup)
      {:ok, comment} =
        Inkfish.Repo.insert(%Inkfish.LineComments.LineComment{
          grade_id: confirmed_grade.id,
          user_id: staff.id,
          path: "Ω_grading_extra.txt",
          line: 3,
          points: Decimal.new("-5.0"),
          text: "To delete"
        })

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn = delete(conn, ~p"/api/v1/staff/line_comments/#{comment.id}")

      assert json_response(conn, 403)
      assert json_response(conn, 403)["error"] == "grade_already_confirmed"
    end

    test "returns 403 when bulk replacing comments on confirmed grade", %{
      conn: conn
    } do
      stock = stock_course()
      staff = stock.staff

      # Create a new feedback grade column and a confirmed grade
      new_grade_column =
        insert(:grade_column, kind: "feedback", assignment: stock.assignment)

      confirmed_feedback_grade =
        insert(:grade,
          grade_column: new_grade_column,
          sub: stock.sub,
          score: Decimal.new("35.0"),
          confirmed: true
        )

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      # Try to use POST grade endpoint to replace comments
      conn =
        post(
          conn,
          ~p"/api/v1/staff/grades?sub_id=#{confirmed_feedback_grade.sub_id}",
          grade: %{
            grade_column_id: confirmed_feedback_grade.grade_column_id,
            line_comments: [
              %{
                "path" => "Ω_grading_extra.txt",
                "line" => 3,
                "points" => "-5.0",
                "text" => "Should fail"
              }
            ]
          }
        )

      assert json_response(conn, 403)
      assert json_response(conn, 403)["error"] == "grade_already_confirmed"
    end
  end

  describe "confirmation workflow" do
    test "creates feedback grade as unconfirmed by default", %{conn: conn} do
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

      assert response_data["confirmed"] == false
      assert response_data["score"] == nil
      assert response_data["preview_score"] == "35.0"
    end

    test "creates number grade as confirmed by default", %{conn: conn} do
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

      assert response_data["confirmed"] == true
      assert response_data["score"] == "8.5"
    end

    test "confirms an unconfirmed feedback grade", %{conn: conn} do
      stock = stock_course()
      grade = stock.grade
      staff = stock.staff

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      {:ok, _lc} =
        Inkfish.LineComments.create_line_comment(
          %{
            grade_id: grade.id,
            user_id: staff.id,
            path: "Ω_grading_extra.txt",
            line: 3,
            points: Decimal.new("-5.0"),
            text: "Style issue"
          },
          ["Ω_grading_extra.txt"]
        )

      conn = post(conn, ~p"/api/v1/staff/grades/#{grade.id}/confirm")
      response_data = json_response(conn, 200)["data"]

      assert response_data["confirmed"] == true
      assert response_data["score"] == "35.0"
    end

    test "unconfirms a confirmed grade", %{conn: conn} do
      stock = stock_course()
      staff = stock.staff
      confirmed_grade = stock.confirmed_grade

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn =
        post(conn, ~p"/api/v1/staff/grades/#{confirmed_grade.id}/unconfirm")

      response_data = json_response(conn, 200)["data"]

      assert response_data["confirmed"] == false
      assert response_data["score"] == nil
    end

    test "returns 404 when confirming non-existent grade", %{conn: conn} do
      staff = insert(:user)
      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn = post(conn, ~p"/api/v1/staff/grades/999999/confirm")
      assert json_response(conn, 404)
    end

    test "updates existing grade with new line_comments preserving student comments",
         %{conn: conn} do
      stock = stock_course()
      sub = stock.sub
      grade_column = stock.grade_column
      staff = stock.staff
      student = stock.student

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

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      conn =
        post(conn, ~p"/api/v1/staff/grades?sub_id=#{sub.id}",
          grade: update_attrs
        )

      response_data = json_response(conn, 201)["data"]

      assert %{
               "id" => fetched_id,
               "score" => nil,
               "preview_score" => "33.0"
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
