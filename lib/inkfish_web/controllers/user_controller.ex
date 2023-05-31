defmodule InkfishWeb.UserController do
  use InkfishWeb, :controller1
  
  alias Inkfish.Users

  plug InkfishWeb.Plugs.RequireUser
  plug :user_check_permission

  def user_check_permission(conn, _foo) do
    id = conn.params["id"] || conn.assigns["current_user_id"]
    IO.inspect({:user_id, id})
    {id, _} = Integer.parse(id)
    user = conn.assigns[:current_user]
    if !user.is_admin && user.id != id do
      conn
      |> put_flash(:error, "Access denied.")
      |> redirect(to: Routes.page_path(conn, :dashboard))
      |> halt
    else
      conn
    end
  end

  def show(conn, %{"id" => id}) do
    user = Users.get_user!(id)
    render(conn, :show, user: user)
  end

  def edit(conn, %{"id" => id}) do
    user = Users.get_user!(id)
    changeset = Users.change_user(user)

    conn
    |> assign(:password_changeset, Users.change_user_password(user))
    |> render(:edit, user: user, changeset: changeset)
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"current_password" => password, "user" => user_params} = params
    user = conn.assigns.current_user

    case Users.update_user_password(user, password, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, ~p"/users/#{user.id}")
        |> redirect(to: Routes.user_path(conn, :show, user))

      {:error, pw_changeset} ->
	IO.inspect {:pwchfail, pw_changeset}
	conn
        |> put_flash(:error, "Changing password failed")
	|> assign(:changeset, Users.change_user(user))
	|> assign(:password_changeset, pw_changeset)
	|> render(:edit, user: user)
    end
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Users.get_user!(id)

    case Users.update_user(user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User updated successfully.")
        |> redirect(to: Routes.user_path(conn, :show, user))

      {:error, %Ecto.Changeset{} = changeset} ->
	conn
	|> assign(:password_changeset, Users.change_user_password(user))
	|> render(:edit, user: user, changeset: changeset)
    end
  end
end
