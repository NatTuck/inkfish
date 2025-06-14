defmodule InkfishWeb.ApiKeyControllerTest do
  use InkfishWeb.ConnCase

  import Inkfish.ApiKeysFixtures
  import Inkfish.Factory

  @create_attrs %{key: "some key"}
  @update_attrs %{key: "some updated key"}
  @invalid_attrs %{key: nil}

  setup %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    {:ok, conn: conn, user: user}
  end

  describe "index" do
    test "lists all apikeys for the current user", %{conn: conn, user: user} do
      key = api_key_fixture(user: user)
      other_user_key = api_key_fixture()

      conn = get(conn, ~p"/apikeys")
      assert html_response(conn, 200) =~ "Listing API Keys"
      assert html_response(conn, 200) =~ key.key
      refute html_response(conn, 200) =~ other_user_key.key
    end
  end

  describe "new API key" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/apikeys/new")
      assert html_response(conn, 200) =~ "New API Key"
    end
  end

  describe "create API key" do
    test "redirects to show when data is valid", %{conn: conn, user: user} do
      conn = post(conn, ~p"/apikeys", api_key: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/apikeys/#{id}"

      conn = get(conn, ~p"/apikeys/#{id}")
      assert html_response(conn, 200) =~ "API Key"
      assert html_response(conn, 200) =~ @create_attrs.key
      assert Repo.get_by!(Inkfish.ApiKeys.ApiKey, id: id).user_id == user.id
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/apikeys", api_key: @invalid_attrs)
      assert html_response(conn, 200) =~ "New API Key"
    end
  end

  describe "edit API key" do
    setup [:create_api_key]

    test "renders form for editing chosen api_key", %{conn: conn, api_key: api_key} do
      conn = get(conn, ~p"/apikeys/#{api_key}/edit")
      assert html_response(conn, 200) =~ "Edit API Key"
    end

    test "does not render for other user's key", %{conn: conn} do
      other_users_key = api_key_fixture()

      assert_error_sent 404, fn ->
        get(conn, ~p"/apikeys/#{other_users_key}/edit")
      end
    end
  end

  describe "update API key" do
    setup [:create_api_key]

    test "redirects when data is valid", %{conn: conn, api_key: api_key} do
      conn = put(conn, ~p"/apikeys/#{api_key}", api_key: @update_attrs)
      assert redirected_to(conn) == ~p"/apikeys/#{api_key}"

      conn = get(conn, ~p"/apikeys/#{api_key}")
      assert html_response(conn, 200) =~ "some updated key"
    end

    test "renders errors when data is invalid", %{conn: conn, api_key: api_key} do
      conn = put(conn, ~p"/apikeys/#{api_key}", api_key: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit API Key"
    end

    test "does not update other user's key", %{conn: conn} do
      other_users_key = api_key_fixture()

      assert_error_sent 404, fn ->
        put(conn, ~p"/apikeys/#{other_users_key}", api_key: @update_attrs)
      end
    end
  end

  describe "delete API key" do
    setup [:create_api_key]

    test "deletes chosen api_key", %{conn: conn, api_key: api_key} do
      conn = delete(conn, ~p"/apikeys/#{api_key}")
      assert redirected_to(conn) == ~p"/apikeys"

      assert_error_sent 404, fn ->
        get(conn, ~p"/apikeys/#{api_key}")
      end
    end

    test "does not delete other user's key", %{conn: conn} do
      other_users_key = api_key_fixture()

      assert_error_sent 404, fn ->
        delete(conn, ~p"/apikeys/#{other_users_key}")
      end
    end
  end

  defp create_api_key(%{user: user}) do
    api_key = api_key_fixture(user: user)
    %{api_key: api_key}
  end
end
