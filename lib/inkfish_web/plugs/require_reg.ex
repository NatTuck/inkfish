defmodule InkfishWeb.Plugs.RequireReg do
  use InkfishWeb, :controller

  alias Inkfish.Users

  def init(args), do: args

  def call(conn, args \\ []) do
    user = conn.assigns[:current_user]
    course = conn.assigns[:course]

    if is_nil(user) or is_nil(course) do
      respond_with_error(conn, 404, "Could not find user or course.")
    else
      reg = Users.find_reg(user, course)

      is_staff = reg && (reg.is_staff || reg.is_prof)

      if is_nil(reg) || (args[:staff] && !is_staff && !user.is_admin) do
        respond_with_error(conn, 403, "Access denied")
      else
        assign(conn, :current_reg, reg)
      end
    end
  end

  def respond_with_error(conn, code, msg) do
    if conn.assigns[:client_mode] == :browser do
      conn
      |> put_flash(:error, msg)
      |> redirect(to: ~p"/")
      |> halt
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(code, JSON.encode!(%{error: msg}))
      |> halt
    end
  end
end
