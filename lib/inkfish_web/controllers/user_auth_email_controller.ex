defmodule InkfishWeb.UserAuthEmailController do
  use InkfishWeb, :controller1

  alias Inkfish.Users
  alias Inkfish.Users.User

  def new(conn, _params) do
    render(conn, :new)
  end

  defp sign_token(salt, data) do
    Phoenix.Token.sign(InkfishWeb.Endpoint, salt, data)
  end

  def create(conn, %{"email" => email}) do
    email = User.normalize_email(email)

    if user = Users.get_user_by_email(email) do
      token = sign_token("auth_email", %{user_id: user.id, email: email})
      url_text = url(~p"/users/auth/#{token}")
      case Users.deliver_user_auth_email(user, url_text) do
	{:ok, _} ->
	  conn
	  |> assign(:page_title, "Auth Email Sent")
	  |> render(:create)
	{:error, msg} ->
	  conn
	  |> put_flash(:error, msg)
	  |> redirect(to: ~p"/")
      end
    else
      token = sign_token("reg_email", %{email: email})
      url_text = url(~p"/users/new/#{token}")
      case Users.deliver_user_reg_email(email, url_text) do
	{:ok, _} ->
	  conn
	  |> assign(:page_title, "Auth Email Sent")
	  |> render(:create)
	{:error, msg} ->
	  conn
	  |> put_flash(:error, msg)
	  |> redirect(to: ~p"/")
      end
    end
  end
end
