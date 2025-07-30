defmodule InkfishWeb.Plugs.RequireReg do
  use InkfishWeb, :controller

  alias Inkfish.Users

  def init(args), do: args

  def call(conn, args \\ []) do
    user = conn.assigns[:current_user]
    course = conn.assigns[:course]

    with {:ok, reg} <- Users.find_reg(user, course) do
      is_staff = reg && (reg.is_staff || reg.is_prof)

      if args[:staff] && !is_staff && !user.is_admin do
        respond_with_error(conn, 403, "Access denied")
      else
        assign(conn, :current_reg, reg)
      end
    else
      _ ->
        respond_with_error(conn, 403, "Registration required")
    end
  end
end
