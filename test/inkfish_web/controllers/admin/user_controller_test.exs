defmodule InkfishWeb.Admin.UserControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  def fixture(:user) do
    insert(:user)
  end

  describe "index" do
    test "lists all users", %{conn: conn} do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/admin/users")

      assert html_response(conn, 200) =~ "Listing Users"
    end
  end

  describe "edit user" do
    setup [:create_user]

    test "renders form for editing chosen user", %{conn: conn, user: user} do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/admin/users/#{user}/edit")

      assert html_response(conn, 200) =~ "Edit User"
    end
  end

  describe "update user" do
    setup [:create_user]

    test "redirects when data is valid", %{conn: conn, user: user} do
      conn =
        conn
        |> login("alice@example.com")
        |> put(~p"/admin/users/#{user}",
          user: %{"nickname" => "Zach"}
        )

      assert redirected_to(conn) == ~p"/admin/users/#{user}"

      conn = get(conn, ~p"/admin/users/#{user}")
      assert html_response(conn, 200) =~ "Zach"
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn =
        conn
        |> login("alice@example.com")
        |> put(~p"/admin/users/#{user}",
          user: %{"email" => "bob"}
        )

      assert html_response(conn, 200) =~ "Edit User"
    end
  end

  describe "delete user" do
    setup [:create_user]

    test "deletes chosen user", %{conn: conn, user: user} do
      conn =
        conn
        |> login("alice@example.com")
        |> delete(~p"/admin/users/#{user}")

      assert redirected_to(conn) == ~p"/admin/users"

      assert_error_sent 404, fn ->
        get(conn, ~p"/admin/users/#{user}")
      end
    end
  end

  defp create_user(_) do
    user = insert(:user)
    {:ok, user: user}
  end
end
