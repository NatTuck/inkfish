defmodule InkfishWeb.UserController do
  use InkfishWeb, :controller1
  
  alias Inkfish.Users
  alias Inkfish.Users.User

  plug :user_check_permission when action not in [:new, :create]

  def user_check_permission(conn, _foo) do
    id = conn.params["id"] || conn.assigns["current_user_id"]
    #IO.inspect({:user_id, id})
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

  def new(conn, %{"token" => token}) do
    case Phoenix.Token.verify(conn, "reg_email", token, max_age: 86400) do
      {:ok, %{email: email}} ->
	changeset = Users.change_user_registration(%User{email: email})
	render(conn, :new, changeset: changeset, token: token)
      :error ->
        conn
        |> put_flash(:error, "Bad token, probably expired. Request another link.")
        |> redirect(to: ~p"/")
    end
  end

  def create(conn, %{"user" => user_params, "token" => token}) do
    case Phoenix.Token.verify(conn, "reg_email", token, max_age: 86400) do
      {:ok, %{email: email}} ->
	e1 = User.normalize_email(Map.get(user_params, "email"))
	if e1 != email do
	  raise "Sorry, no"
	end
	
	case Users.create_user(user_params) do
	  {:ok, user} ->
	    conn
	    |> put_session(:user_id, user.id)
	    |> put_flash(:info, "Welcome, new user.")
	    |> redirect(to: ~p"/dashboard")

	  {:error, %Ecto.Changeset{} = changeset} ->
	    render(conn, :new, changeset: changeset)
	end
      :error ->
	conn
	|> put_flash(:error, "Bad token, probably expired. Request another link.")
	|> redirect(to: ~p"/")
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

    case Users.update_user_password(user, user_params) do
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
