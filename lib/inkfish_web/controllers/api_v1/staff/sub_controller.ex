defmodule InkfishWeb.ApiV1.Staff.SubController do
  use InkfishWeb, :controller

  alias Inkfish.Subs
  alias InkfishWeb.Plugs

  action_fallback InkfishWeb.FallbackController

  plug InkfishWeb.Plugs.RequireApiUser

  plug Plugs.FetchItem,
       [sub: "id"]
       when action in [:show]

  plug Plugs.FetchItem,
       [assignment: "assignment_id"]
       when action in [:index]

  plug Plugs.RequireReg, staff: true

  def index(conn, params) do
    case Map.fetch(params, "assignment_id") do
      {:ok, asg_id_param} when is_binary(asg_id_param) and asg_id_param != "" ->
        asg_id = String.to_integer(asg_id_param)
        page = Map.get(params, "page", "0") |> String.to_integer()
        subs = Subs.list_subs_for_staff_api(asg_id, page)

        conn
        |> put_view(InkfishWeb.ApiV1.Staff.SubJSON)
        |> render(:index, subs: subs)

      _ ->
        conn
        |> put_status(:bad_request)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:error,
          message: "assignment_id is required and must be a non-empty string"
        )
    end
  end

  def show(conn, _params) do
    sub = conn.assigns.sub

    conn
    |> put_view(InkfishWeb.ApiV1.Staff.SubJSON)
    |> render(:show, sub: sub)
  end
end
