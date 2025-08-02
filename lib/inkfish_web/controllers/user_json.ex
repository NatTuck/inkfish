defmodule InkfishWeb.UserJSON do
  use InkfishWeb, :json

  alias Inkfish.Users.User

  def index(%{users: users}) do
    %{data: for(user <- users, do: data(user))}
  end

  def show(%{user: nil}), do: %{data: nil}

  def show(%{user: user}) do
    %{data: data(user)}
  end

  def data(nil), do: nil

  def data(%User{} = user) do
    %{
      id: user.id,
      name: user_display_name(user)
    }
  end
end
