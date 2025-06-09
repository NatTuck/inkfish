defmodule InkfishWeb.AgJobController do
  use InkfishWeb, :controller1

  alias Inkfish.AgJobs
  # alias Inkfish.AgJobs.AgJob

  def index(conn, _params) do
    ag_jobs = AgJobs.list_ag_jobs_for_display()
    render(conn, :index, ag_jobs: ag_jobs)
  end
end
