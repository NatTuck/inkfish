defmodule InkfishWeb.Plugs.UserSession do
  use InkfishWeb, :controller

  def require_no_session(conn, _args) do
    user = conn.assigns[:current_user]

    if user do
      conn
      |> put_flash(:error, "Expected no user session.")
      |> redirect(to: ~p"/dashboard")
      |> halt
    else
      conn
    end
  end

  def require_user_session(conn, _args) do
    user = conn.assigns[:current_user]

    if user do
      conn
    else
      respond_with_error(conn, 403, "Please log in.")
    end
  end

  def require_admin_session(conn, _args) do
    user = conn.assigns[:current_user]

    if user && user.is_admin do
      conn
    else
      respond_with_error(conn, 403, "Access denied.")
    end
  end
end
