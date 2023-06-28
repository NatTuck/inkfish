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
      Users.deliver_user_auth_email(
	user,
	url(~p"/users/auth/#{token}")
      )
    else
      token = sign_token("reg_email", %{email: email})
      Users.deliver_user_reg_email(
	user,
	url(~p"/users/new/#{token}")
      )
    end

    conn
    |> assign(:page_title, "Auth Email Sent")
    |> render(:create)
  end
end
