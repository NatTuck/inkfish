defmodule InkfishWeb.UserJSON do
  import InkfishWeb.ViewHelpers

  def show(%{user: user}) do
    %{
      id: user.id,
      name: user_display_name(user)
    }
  end
end
