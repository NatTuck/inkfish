defmodule InkfishWeb.Plugs.RequireApiUser do
  use InkfishWeb, :controller
  use OK.Pipe

  alias Inkfish.ApiKeys

  def init(args), do: args

  def call(conn, _args \\ []) do
    result =
      {:ok, conn}
      ~>> get_auth_key()
      ~>> get_user_from_key()

    case result do
      {:ok, conn1} ->
        conn1

      {:error, msg} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, ~s({"error": "#{msg}"}))
        |> halt
    end
  end

  def get_auth_key(conn) do
    hdrs = conn.req_headers |> Enum.into(%{})
    auth = Map.get(hdrs, "x-auth")

    if auth do
      {:ok, {conn, auth}}
    else
      {:error, "Requires x-auth header."}
    end
  end

  def get_user_from_key({conn, auth}) do
    case ApiKeys.get_user_by_api_key(auth) do
      {:ok, user} ->
        conn = conn
        {:ok, assign(conn, :current_user, user)}

      {:error, msg} ->
        {:error, msg}
    end
  end
end
