defmodule InkfishWeb.ApiV1.Staff.LineCommentControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create" do
    test "marks a comment from the api as machine written", %{conn: conn} do
      stock = stock_course()
      grade = stock.grade
      staff = stock.staff

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      params = %{
        "line_comment" => %{
          "path" => "Ω_grading_extra.txt",
          "line" => 1,
          "points" => "-1.0",
          "text" => "From a bot"
        }
      }

      conn =
        post(conn, ~p"/api/v1/staff/grades/#{grade.id}/line_comments", params)

      data = json_response(conn, 201)["data"]

      assert data["text"] == "🤖 From a bot 🤖"
    end

    test "marks batch comments from the api as machine written", %{conn: conn} do
      stock = stock_course()
      sub = stock.sub
      grade_column = stock.grade_column
      staff = stock.staff

      api_key = insert(:api_key, user: staff)
      conn = put_req_header(conn, "x-auth", api_key.key)

      attrs = %{
        grade_column_id: grade_column.id,
        line_comments: [
          %{
            "path" => "Ω_grading_extra.txt",
            "line" => 3,
            "points" => "-5.0",
            "text" => "Bot note"
          }
        ]
      }

      conn =
        post(conn, ~p"/api/v1/staff/grades?sub_id=#{sub.id}", grade: attrs)

      data = json_response(conn, 201)["data"]

      assert [comment] = data["line_comments"]
      assert comment["text"] == "🤖 Bot note 🤖"
    end
  end
end
