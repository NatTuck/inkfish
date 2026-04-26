defmodule InkfishWeb.Plugs.RequireApiAdmin do
  use InkfishWeb, :controller

  def init(args), do: args

  def call(conn, _args \\ []) do
    user = conn.assigns[:current_user]

    if user.is_admin do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(403, ~s({"error": "Admin access required"}))
      |> halt()
    end
  end
end
