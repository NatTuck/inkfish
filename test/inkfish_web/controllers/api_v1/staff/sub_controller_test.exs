defmodule InkfishWeb.ApiV1.Staff.SubControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.SubsFixtures

  alias Inkfish.Subs.Sub

  @create_attrs %{
    active: true,
    late_penalty: "120.5",
    score: "120.5",
    hours_spent: "120.5",
    note: "some note",
    ignore_late_penalty: true
  }
  @update_attrs %{
    active: false,
    late_penalty: "456.7",
    score: "456.7",
    hours_spent: "456.7",
    note: "some updated note",
    ignore_late_penalty: false
  }
  @invalid_attrs %{active: nil, late_penalty: nil, score: nil, hours_spent: nil, note: nil, ignore_late_penalty: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all subs", %{conn: conn} do
      conn = get(conn, ~p"/api/api_v1/staff/subs")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create sub" do
    test "renders sub when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/api_v1/staff/subs", sub: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/api_v1/staff/subs/#{id}")

      assert %{
               "id" => ^id,
               "active" => true,
               "hours_spent" => "120.5",
               "ignore_late_penalty" => true,
               "late_penalty" => "120.5",
               "note" => "some note",
               "score" => "120.5"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/api_v1/staff/subs", sub: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update sub" do
    setup [:create_sub]

    test "renders sub when data is valid", %{conn: conn, sub: %Sub{id: id} = sub} do
      conn = put(conn, ~p"/api/api_v1/staff/subs/#{sub}", sub: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/api_v1/staff/subs/#{id}")

      assert %{
               "id" => ^id,
               "active" => false,
               "hours_spent" => "456.7",
               "ignore_late_penalty" => false,
               "late_penalty" => "456.7",
               "note" => "some updated note",
               "score" => "456.7"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, sub: sub} do
      conn = put(conn, ~p"/api/api_v1/staff/subs/#{sub}", sub: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete sub" do
    setup [:create_sub]

    test "deletes chosen sub", %{conn: conn, sub: sub} do
      conn = delete(conn, ~p"/api/api_v1/staff/subs/#{sub}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/api_v1/staff/subs/#{sub}")
      end
    end
  end

  defp create_sub(_) do
    sub = sub_fixture()
    %{sub: sub}
  end
end
