defmodule InkfishWeb.ApiKeyController do
  use InkfishWeb, :controller

  alias Inkfish.ApiKeys
  alias Inkfish.ApiKeys.ApiKey

  def index(conn, _params) do
    api_keys = ApiKeys.list_user_apikeys(conn.assigns.current_user)
    render(conn, :index, page_title: "Your API Keys", api_keys: api_keys)
  end

  def new(conn, _params) do
    changeset = ApiKeys.change_api_key(%ApiKey{key: Inkfish.Text.gen_uuid()})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"api_key" => api_key_params}) do
    case ApiKeys.create_api_key(conn.assigns.current_user, api_key_params) do
      {:ok, api_key} ->
        conn
        |> put_flash(:info, "API key created successfully.")
        |> redirect(to: ~p"/api_keys/#{api_key}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    api_key = get_and_authorize_key(conn.assigns.current_user, id)
    render(conn, :show, page_title: "API Key", api_key: api_key)
  end

  def delete(conn, %{"id" => id}) do
    api_key = get_and_authorize_key(conn.assigns.current_user, id)
    {:ok, _api_key} = ApiKeys.delete_api_key(api_key)

    conn
    |> put_flash(:info, "API key deleted successfully.")
    |> redirect(to: ~p"/api_keys")
  end

  defp get_and_authorize_key(current_user, id) do
    api_key = ApiKeys.get_api_key!(id)

    if api_key.user_id == current_user.id do
      api_key
    else
      nil
    end
  end
end
