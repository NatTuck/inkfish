defmodule InkfishWeb.RegView do
  alias InkfishWeb.UserJson

  import InkfishWeb.ViewHelpers

  def show(%{reg: reg}) do
    user = get_assoc(reg, :user)

    %{
      user: UserJson.show(user)
    }
  end
end
