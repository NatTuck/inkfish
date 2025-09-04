defmodule InkfishWeb.Plugs.FetchUser do
  use InkfishWeb, :controller

  alias Inkfish.Users.User
  alias Inkfish.Repo.Cache

  def init(args), do: args

  def call(conn, _args) do
    user_id = get_session(conn, :user_id)

    case Cache.get(User, user_id) do
      {:ok, user} ->
        token = make_token(conn, user)
        ruid = get_session(conn, :real_uid)

        conn
        |> assign(:current_user_id, user_id)
        |> assign(:current_user, user)
        |> assign(:current_user_token, token)
        |> assign(:current_ruid, ruid)

      _else ->
        conn
        |> assign(:current_user_id, nil)
        |> assign(:current_user, nil)
        |> assign(:current_user_token, "")
        |> assign(:current_ruid, nil)
    end
  end

  def make_token(conn, %User{} = user) do
    Phoenix.Token.sign(conn, "user_id", user.id)
  end

  def make_token(_conn, nil) do
    ""
  end
end
