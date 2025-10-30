defmodule InkfishWeb.AgJobController do
  use InkfishWeb, :controller

  alias Inkfish.AgJobs
  alias Inkfish.AgJobs.AgJob

  def index(conn, _params) do
    ag_jobs = AgJobs.list_ag_jobs_for_display()

    done_jobs = Enum.filter(ag_jobs, &(AgJob.ag_job_status(&1) == :done))
    curr_jobs = Enum.filter(ag_jobs, &(AgJob.ag_job_status(&1) == :running))
    wait_jobs = Enum.filter(ag_jobs, &(AgJob.ag_job_status(&1) == :ready))

    conn
    |> assign(:page_title, "Autograding Jobs")
    |> render(:index,
      wait_jobs: wait_jobs,
      curr_jobs: curr_jobs,
      done_jobs: done_jobs
    )
  end

  def poll(conn, _params) do
    AgJobs.Server.poll()

    conn
    |> put_flash(:info, "Did poll.")
    |> redirect(to: ~p"/ag_jobs")
  end
end
