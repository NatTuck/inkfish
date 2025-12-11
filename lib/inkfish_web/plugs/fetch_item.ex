defmodule InkfishWeb.Plugs.FetchItem do
  use InkfishWeb, :controller

  alias Inkfish.Repo.Cache
  alias Inkfish.Repo.Info

  def init(args), do: args

  def call(conn, [{target, param}]) do
    IO.inspect({conn.params, target, param})

    with {:ok, id} <- Map.fetch(conn.params, to_string(param)),
         {:ok, mod} <- Info.slug_to_mod(target),
         {:ok, item} <- Cache.get(mod, id),
         {:ok, conn} <- assign_path(conn, item) do
      IO.inspect(item)
      conn
    else
      _error ->
        # IO.inspect({:fetch_item, {target, param}, _error})

        if conn.assigns[:client_mode] == :browser do
          conn
          |> put_flash(:error, "Something was missing")
          |> redirect(to: ~p"/")
          |> halt()
        else
          conn
          |> put_status(:not_found)
          |> put_view(InkfishWeb.ErrorJSON)
          |> render(:not_found)
          |> halt()
        end
    end
  end

  def assign_path(conn, item) do
    name = Info.slug(item.__struct__)
    conn = assign(conn, name, item)
    imod = item.__struct__

    case Info.parent_field(imod) do
      {:ok, pfield} ->
        parent = Map.get(item, pfield)
        assign_path(conn, parent)

      _error ->
        {:ok, conn}
    end
  end
end
