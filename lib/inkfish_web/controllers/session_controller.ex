defmodule InkfishWeb.SessionController do
  use InkfishWeb, :controller

  alias Inkfish.Users

  def create(conn, %{"email" => email, "password" => pass}) do
    user = Users.get_user_by_email_and_password(email, pass)

    if user do
      conn
      |> put_session(:user_id, user.id)
      |> put_flash(:info, "Logged in as #{user.email}")
      |> redirect(to: ~p"/dashboard")
    else
      conn
      |> put_flash(:error, "Login failed.")
      |> redirect(to: ~p"/")
    end
  end

  def delete(conn, _params) do
    conn
    |> delete_session(:user_id)
    |> put_flash(:info, "Logged out.")
    |> redirect(to: ~p"/")
  end

  def resume(conn, _params) do
    user = Users.get_user!(get_session(conn, :real_uid))

    conn
    |> delete_session(:real_uid)
    |> put_session(:user_id, user.id)
    |> put_flash(:info, "No longer impersonating anyone.")
    |> redirect(to: ~p"/")
  end
end
