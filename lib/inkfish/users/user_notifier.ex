defmodule Inkfish.Users.UserNotifier do
  import Swoosh.Email

  alias Inkfish.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Inkfish", "inkfish@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver link to register account.
  """
  def deliver_reg_email(email, url) do
    deliver(email, "Inkfish registration link", """

    ==============================

    Hi #{email},

    You can create your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset password.
  """
  def deliver_user_auth_email(user, url) do
    deliver(user.email, "Inkfish authentication link", """

    ==============================

    Hi #{user.email},

    You can log in to Inkfish with the following link:

    #{url}

    Sharing this link is equivent to sharing your password, which
    is generally a bad idea.

    ==============================
    """)
  end
end
