defmodule InkfishWeb.UserAuthEmailController do
  use InkfishWeb, :controller

  alias Inkfish.Users
  alias Inkfish.Users.User

  alias Inkfish.Mailer

  def new(conn, _params) do
    render(conn, :new)
  end

  defp sign_token(salt, data) do
    Phoenix.Token.sign(InkfishWeb.Endpoint, salt, data)
  end

  def create(conn, %{"email" => email}) do
    email = User.normalize_email(email)
    {_name, from} = Mailer.send_from()

    IO.inspect({:email_to, email, :from, from})

    if user = Users.get_user_by_email(email) do
      token = sign_token("auth_email", %{user_id: user.id, email: email})
      url_text = url(~p"/users/auth/#{token}")

      IO.inspect({:found_user, user})

      case Users.deliver_user_auth_email(user, url_text) do
        {:ok, _} ->
          conn
          |> assign(:page_title, "Auth Email Sent")
          |> assign(:from_email, from)
          |> render(:create)

        {:error, msg} ->
          conn
          |> put_flash(:error, msg)
          |> redirect(to: ~p"/")
      end
    else
      IO.inspect({:no_user_for, email})

      token = sign_token("reg_email", %{email: email})
      url_text = url(~p"/users/new/#{token}")

      case Users.deliver_user_reg_email(email, url_text) do
        {:ok, _} ->
          conn
          |> assign(:page_title, "Auth Email Sent")
          |> assign(:from_email, from)
          |> render(:create)

        {:error, msg} ->
          conn
          |> put_flash(:error, msg)
          |> redirect(to: ~p"/")
      end
    end
  end

  def show(conn, %{"token" => token}) do
    case Phoenix.Token.verify(conn, "auth_email", token, max_age: 86400) do
      {:ok, %{email: email}} ->
        user = Users.get_user_by_email(email)

        if user do
          conn
          |> put_session(:user_id, user.id)
          |> put_flash(
            :info,
            "Logged in as #{user.email}, don't forget to change your password."
          )
          |> redirect(to: ~p"/dashboard")
        else
          conn
          |> put_flash(:error, "Login link failed.")
          |> redirect(to: ~p"/")
        end

      {:error, _} ->
        conn
        |> put_flash(
          :error,
          "Bad token, probably expired. Request another link."
        )
        |> redirect(to: ~p"/")
    end
  end
end
