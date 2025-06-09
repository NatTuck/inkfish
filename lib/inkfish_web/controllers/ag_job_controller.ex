defmodule InkfishWeb.AgJobController do
  use InkfishWeb, :controller1

  alias Inkfish.AgJobs
  # alias Inkfish.AgJobs.AgJob

  def index(conn, _params) do
    ag_jobs = AgJobs.list_ag_jobs_for_display()

    conn
    |> assign(:page_title, "Autograding Jobs")
    |> render(:index, ag_jobs: ag_jobs)
  end

  def poll(conn, _params) do
    AgJobs.Server.poll()

    conn
    |> put_flash(:info, "Did poll.")
    |> redirect(to: ~p"/ag_jobs")
  end
end
