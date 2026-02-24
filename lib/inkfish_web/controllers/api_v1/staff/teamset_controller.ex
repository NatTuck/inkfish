defmodule InkfishWeb.ApiV1.Staff.TeamsetController do
  use InkfishWeb, :controller

  alias Inkfish.Teams
  alias Inkfish.Repo

  action_fallback InkfishWeb.FallbackController

  alias InkfishWeb.Plugs

  plug Plugs.RequireApiUser

  plug Plugs.FetchItem,
       [course: "course_id"]
       when action in [:create]

  plug Plugs.RequireReg, staff: true

  def create(conn, %{"course_id" => _course_id}) do
    course = conn.assigns[:course]

    teamset_params =
      conn.params["teamset"]
      |> Map.put("course_id", course.id)

    case Teams.create_teamset(teamset_params) do
      {:ok, teamset} ->
        teamset = Repo.preload(teamset, :course)

        conn
        |> put_status(:created)
        |> put_view(InkfishWeb.ApiV1.Staff.TeamsetJSON)
        |> render(:show, teamset: teamset)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end
end
