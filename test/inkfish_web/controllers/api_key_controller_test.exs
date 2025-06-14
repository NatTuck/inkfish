defmodule InkfishWeb.ApiKeyControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.ApiKeysFixtures

  @create_attrs %{key: "some key"}
  @update_attrs %{key: "some updated key"}
  @invalid_attrs %{key: nil}

  describe "index" do
    test "lists all api_key", %{conn: conn} do
      conn = get(conn, ~p"/api_key")
      assert html_response(conn, 200) =~ "Listing Api key"
    end
  end

  describe "new api_key" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/api_key/new")
      assert html_response(conn, 200) =~ "New Api key"
    end
  end

  describe "create api_key" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api_key", api_key: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/api_key/#{id}"

      conn = get(conn, ~p"/api_key/#{id}")
      assert html_response(conn, 200) =~ "Api key #{id}"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api_key", api_key: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Api key"
    end
  end

  describe "edit api_key" do
    setup [:create_api_key]

    test "renders form for editing chosen api_key", %{conn: conn, api_key: api_key} do
      conn = get(conn, ~p"/api_key/#{api_key}/edit")
      assert html_response(conn, 200) =~ "Edit Api key"
    end
  end

  describe "update api_key" do
    setup [:create_api_key]

    test "redirects when data is valid", %{conn: conn, api_key: api_key} do
      conn = put(conn, ~p"/api_key/#{api_key}", api_key: @update_attrs)
      assert redirected_to(conn) == ~p"/api_key/#{api_key}"

      conn = get(conn, ~p"/api_key/#{api_key}")
      assert html_response(conn, 200) =~ "some updated key"
    end

    test "renders errors when data is invalid", %{conn: conn, api_key: api_key} do
      conn = put(conn, ~p"/api_key/#{api_key}", api_key: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Api key"
    end
  end

  describe "delete api_key" do
    setup [:create_api_key]

    test "deletes chosen api_key", %{conn: conn, api_key: api_key} do
      conn = delete(conn, ~p"/api_key/#{api_key}")
      assert redirected_to(conn) == ~p"/api_key"

      assert_error_sent 404, fn ->
        get(conn, ~p"/api_key/#{api_key}")
      end
    end
  end

  defp create_api_key(_) do
    api_key = api_key_fixture()
    %{api_key: api_key}
  end
end
