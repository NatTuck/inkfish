defmodule InkfishWeb.ApiKeyController do
  use InkfishWeb, :controller1

  alias Inkfish.ApiKeys
  alias Inkfish.ApiKeys.ApiKey

  def index(conn, _params) do
    api_key = ApiKeys.list_api_key()
    render(conn, :index, api_key_collection: api_key)
  end

  def new(conn, _params) do
    changeset = ApiKeys.change_api_key(%ApiKey{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"api_key" => api_key_params}) do
    case ApiKeys.create_api_key(api_key_params) do
      {:ok, api_key} ->
        conn
        |> put_flash(:info, "Api key created successfully.")
        |> redirect(to: ~p"/api_key/#{api_key}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    api_key = ApiKeys.get_api_key!(id)
    render(conn, :show, api_key: api_key)
  end

  def edit(conn, %{"id" => id}) do
    api_key = ApiKeys.get_api_key!(id)
    changeset = ApiKeys.change_api_key(api_key)
    render(conn, :edit, api_key: api_key, changeset: changeset)
  end

  def update(conn, %{"id" => id, "api_key" => api_key_params}) do
    api_key = ApiKeys.get_api_key!(id)

    case ApiKeys.update_api_key(api_key, api_key_params) do
      {:ok, api_key} ->
        conn
        |> put_flash(:info, "Api key updated successfully.")
        |> redirect(to: ~p"/api_key/#{api_key}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, api_key: api_key, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    api_key = ApiKeys.get_api_key!(id)
    {:ok, _api_key} = ApiKeys.delete_api_key(api_key)

    conn
    |> put_flash(:info, "Api key deleted successfully.")
    |> redirect(to: ~p"/api_key")
  end
end
