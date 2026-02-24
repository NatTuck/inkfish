defmodule InkfishWeb.ApiV1.Staff.CourseController do
  use InkfishWeb, :controller

  alias Inkfish.Repo

  action_fallback InkfishWeb.FallbackController

  alias InkfishWeb.Plugs

  plug Plugs.RequireApiUser

  plug Plugs.FetchItem,
       [course: "id"]
       when action in [:show]

  plug Plugs.RequireReg, staff: true

  def show(conn, %{"id" => _id}) do
    course =
      conn.assigns[:course]
      |> Repo.preload([:buckets, :teamsets, :solo_teamset])

    conn
    |> put_view(InkfishWeb.ApiV1.Staff.CourseJSON)
    |> render(:show, course: course)
  end
end
