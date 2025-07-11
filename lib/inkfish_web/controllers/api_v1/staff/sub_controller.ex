defmodule InkfishWeb.ApiV1.Staff.SubController do
  use InkfishWeb, :controller

  alias Inkfish.Subs
  alias Inkfish.Subs.Sub

  action_fallback InkfishWeb.FallbackController

  def index(conn, _params) do
    subs = Subs.list_subs()
    render(conn, :index, subs: subs)
  end

  def create(conn, %{"sub" => sub_params}) do
    with {:ok, %Sub{} = sub} <- Subs.create_sub(sub_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/api_v1/staff/subs/#{sub}")
      |> render(:show, sub: sub)
    end
  end

  def show(conn, %{"id" => id}) do
    sub = Subs.get_sub!(id)
    render(conn, :show, sub: sub)
  end

  def update(conn, %{"id" => id, "sub" => sub_params}) do
    sub = Subs.get_sub!(id)

    with {:ok, %Sub{} = sub} <- Subs.update_sub(sub, sub_params) do
      render(conn, :show, sub: sub)
    end
  end

  def delete(conn, %{"id" => id}) do
    sub = Subs.get_sub!(id)

    with {:ok, %Sub{}} <- Subs.delete_sub(sub) do
      send_resp(conn, :no_content, "")
    end
  end
end
