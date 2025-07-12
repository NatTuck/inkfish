defmodule InkfishWeb.LineCommentControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  alias Inkfish.LineComments.LineComment

  def fixture(:line_comment) do
    insert(:line_comment)
  end

  setup %{conn: conn} do
    %{staff: staff, grade: grade} = stock_course()
    lc = insert(:line_comment, grade: grade, user: staff)

    {:ok,
     grade: grade,
     staff: staff,
     line_comment: lc,
     conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create line_comment" do
    test "renders line_comment when data is valid", %{
      conn: conn,
      staff: staff,
      grade: grade
    } do
      params = params_for(:line_comment, user: staff, grade: grade)

      conn =
        conn
        |> login(staff)
        |> post(~p"/ajax/staff/grades/#{grade}/line_comments",
          line_comment: params
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/ajax/staff/line_comments/#{id}")

      assert %{
               "id" => ^id,
               "line" => 10,
               "path" => "hw03/main.c",
               "points" => "-5.0"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      staff: staff,
      grade: grade
    } do
      params = %{points: nil}

      conn =
        conn
        |> login(staff)
        |> post(~p"/ajax/staff/grades/#{grade}/line_comments",
          line_comment: params
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update line_comment" do
    test "renders line_comment when data is valid", %{
      conn: conn,
      line_comment: %LineComment{id: id} = line_comment,
      staff: staff
    } do
      params = %{points: "7.3"}

      conn =
        conn
        |> login(staff)
        |> put(~p"/ajax/staff/line_comments/#{line_comment}",
          line_comment: params
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/ajax/staff/line_comments/#{id}")

      assert %{"points" => "7.3"} = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      line_comment: line_comment,
      staff: staff
    } do
      params = %{points: nil}

      conn =
        conn
        |> login(staff)
        |> put(~p"/ajax/staff/line_comments/#{line_comment}",
          line_comment: params
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete line_comment" do
    test "deletes chosen line_comment", %{
      conn: conn,
      line_comment: line_comment,
      staff: staff
    } do
      conn =
        conn
        |> login(staff)
        |> delete(
          ~p"/ajax/staff/line_comments/#{line_comment}"
        )

      assert response(conn, 200)

      assert_error_sent 404, fn ->
        get(
          conn,
          ~p"/ajax/staff/line_comments/#{line_comment}"
        )
      end
    end
  end
end
