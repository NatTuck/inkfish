defmodule InkfishWeb.ApiV1.Staff.GradeControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.GradesFixtures

  alias Inkfish.Grades.Grade

  @create_attrs %{
    score: "120.5",
    log_uuid: "some log_uuid"
  }
  @update_attrs %{
    score: "456.7",
    log_uuid: "some updated log_uuid"
  }
  @invalid_attrs %{score: nil, log_uuid: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all grades", %{conn: conn} do
      conn = get(conn, ~p"/api/api_v1/staff/grades")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create grade" do
    test "renders grade when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/api_v1/staff/grades", grade: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/api_v1/staff/grades/#{id}")

      assert %{
               "id" => ^id,
               "log_uuid" => "some log_uuid",
               "score" => "120.5"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/api_v1/staff/grades", grade: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete grade" do
    setup [:create_grade]

    test "deletes chosen grade", %{conn: conn, grade: grade} do
      conn = delete(conn, ~p"/api/api_v1/staff/grades/#{grade}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/api_v1/staff/grades/#{grade}")
      end
    end
  end

  defp create_grade(_) do
    grade = grade_fixture()
    %{grade: grade}
  end
end
