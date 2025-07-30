defmodule InkfishWeb.UserControllerTest do
  use InkfishWeb.ConnCase
  import Inkfish.Factory

  describe "edit user" do
    setup [:create_user]

    test "renders form for editing chosen user", %{conn: conn, user: user} do
      conn =
        conn
        |> login("alice@example.com")
        |> get(~p"/users/#{user}/edit")

      assert html_response(conn, 200) =~ "Edit User"
    end
  end

  describe "update user" do
    setup [:create_user]

    test "redirects when data is valid", %{conn: conn, user: user} do
      conn =
        conn
        |> login("alice@example.com")
        |> put(~p"/users/#{user}", user: %{nickname: "Rob"})

      assert redirected_to(conn) == ~p"/users/#{user}"

      conn = get(conn, ~p"/users/#{user}")
      assert html_response(conn, 200) =~ "Rob"
    end
  end

  defp create_user(_) do
    user = insert(:user)
    {:ok, user: user}
  end
end
