defmodule InkfishWeb.Plugs.UserSession do
  use InkfishWeb, :controller
  
  alias Inkfish.Users

  def require_no_session(conn, _args) do
    user = conn.assigns[:current_user]

    if user do
      conn
      |> put_flash(:error, "Expected no user session.")
      |> redirect(to: Routes.page_path(conn, :dashboard))
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
      conn
      |> put_flash(:error, "Please log in.")
      |> redirect(to: Routes.page_path(conn, :index))
      |> halt
    end
  end
  
  def require_admin_session(conn, _args) do
    user = conn.assigns[:current_user]

    if user && user.is_admin do
      conn
    else
      conn
      |> put_flash(:error, "Access denied.")
      |> redirect(to: Routes.page_path(conn, :index))
      |> halt
    end
  end
  
  def require_staff_session(conn, _args) do
    user = conn.assigns[:current_user]
    course = conn.assigns[:current_course]

    reg = Users.find_reg(user, course)
    if reg && (reg.is_prof || reg.is_staff) do
      conn
    else
      conn
      |> put_flash(:error, "Access denied.")
      |> redirect(to: Routes.page_path(conn, :index))
      |> halt
    end
  end
end
