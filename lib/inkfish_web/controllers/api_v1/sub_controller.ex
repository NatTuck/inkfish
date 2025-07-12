defmodule InkfishWeb.ApiV1.SubController do
  use InkfishWeb, :controller

  alias Inkfish.Subs
  alias Inkfish.Assignments
  alias Inkfish.Users
  alias Inkfish.Teams

  action_fallback InkfishWeb.FallbackController

  alias InkfishWeb.Plugs

  plug Plugs.RequireApiUser

  plug Plugs.FetchItem,
       [sub: "id"]
       when action in [:show]

  plug Plugs.FetchItem,
       [assignment: "assignment_id"]
       when action in [:index]

  plug Plugs.RequireReg when action not in [:create]

  # There are intentinally no update or delete functions
  # here; do not add them.

  def index(conn, params) do
    asg = conn.assigns[:assignment]
    user_reg = conn.assigns[:current_reg]

    page = Map.get(params, "page", "0") |> String.to_integer()

    subs = Subs.list_subs_for_api(asg.id, user_reg.id, page)

    conn
    |> put_view(InkfishWeb.ApiV1.SubJSON)
    |> render(:index, subs: subs)
  end

  def show(conn, _params) do
    sub =
      conn.assigns.sub
      |> Subs.preload_upload()

    conn
    |> put_view(InkfishWeb.ApiV1.SubJSON)
    |> render(:show, sub: sub)
  end

  @doc """
  This accepts a request with an x-auth header simulating
  a form like this:

  <form type="multipart">
    <input name="sub[upload]" type="file">
    <input name="sub[assignment_id]">
    <input name="sub[hours_spent]">
  </form>
  """
  def create(conn, %{"sub" => sub_params}) do
    user = conn.assigns[:current_user]

    with {:ok, asg_id} <- fetch_key(sub_params, "assignment_id"),
         {:ok, upload} <- fetch_key(sub_params, "upload"),
         asg when not is_nil(asg) <- Assignments.get_assignment_path(asg_id) do
      reg = Users.find_reg(user, asg.bucket.course)
      team = Teams.get_active_team(asg, reg)

      sub_params =
        sub_params
        |> Map.put("team_id", team.id)
        |> Map.put("reg_id", reg.id)

      upload_params = %{
        "upload" => upload,
        "user_id" => user.id
      }

      case Subs.create_sub_with_upload(sub_params, upload_params) do
        {:ok, sub} ->
          conn
          |> put_status(:created)
          |> put_view(InkfishWeb.ApiV1.SubJSON)
          |> render(:show, sub: sub)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(InkfishWeb.ChangesetJSON)
          |> render(:error, changeset: changeset)
      end
    else
      nil ->
        conn
        |> put_status(:bad_request)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:error, message: "assignment_id not found")

      {:error, key} ->
        conn
        |> put_status(:bad_request)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:error, message: "#{key} is required")
    end
  end

  defp fetch_key(map, key) do
    case Map.fetch(map, key) do
      {:ok, val} -> {:ok, val}
      :error -> {:error, key}
    end
  end
end
