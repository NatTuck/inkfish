defmodule InkfishWeb.SessionControllerTest do
  use InkfishWeb.ConnCase
  
  test "log in", %{conn: conn} do
    form_data = %{
      "email" => "alice@example.com",
      "password" => "alicealice"
    }
    conn = post(conn, "/session", form_data)
    assert Phoenix.Flash.get(conn.assigns[:flash], :info) == "Logged in as alice@example.com"
    assert redirected_to(conn, 302) == "/dashboard"
  end
  
  test "log out", %{conn: conn} do
    conn = conn
    |> login("alice@example.com")
    |> delete("/session")
    assert Phoenix.Flash.get(conn.assigns[:flash], :info) == "Logged out."
    assert get_session(conn, :user_id) == nil
  end
end
