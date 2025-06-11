defmodule Inkfish.AgJobs do
  @moduledoc """
  The AgJobs context.
  """

  import Ecto.Query, warn: false
  alias Inkfish.Repo

  alias Inkfish.AgJobs.AgJob
  alias Inkfish.Subs.Sub

  @doc """
  Returns the list of ag_jobs.

  ## Examples

      iex> list_ag_jobs()
      [%AgJob{}, ...]

  """
  def list_ag_jobs do
    Repo.all(AgJob)
  end

  def list_ag_jobs_for_display do
    Repo.all(
      from(ag in AgJob,
        preload: [sub: [reg: [:user, :course], assignment: []]]
      )
    )
  end

  def list_curr_ag_jobs do
    Repo.all(
      from(job in AgJob,
        where: not is_nil(job.started_at) and is_nil(job.finished_at),
        preload: [sub: [grades: [:grade_column]]]
      )
    )
  end

  def count_user_jobs(user_id) do
    query =
      from(ag in AgJob,
        inner_join: sub in assoc(ag, :sub),
        inner_join: reg in assoc(sub, :reg),
        where: reg.user_id == ^user_id
      )

    Repo.aggregate(query, :count)
  end

  def start_next_ag_job() do
    Repo.transaction(fn ->
      job0 =
        Repo.one(
          from(job in AgJob,
            order_by: [job.prio, job.inserted_at],
            where: is_nil(job.started_at)
          )
        )

      if is_nil(job0) do
        Repo.rollback(:no_more_work)
      end

      update_ag_job(job0, %{started_at: LocalTime.now()})

      job1 = get_ag_job(job0.id)

      if is_nil(job0) do
        Repo.rollback(:no_more_work)
      end

      job1
    end)
  end

  @doc """
  Gets a single ag_job.

  Raises `Ecto.NoResultsError` if the Ag job does not exist.

  ## Examples

  iex> get_ag_job!(123)
  %AgJob{}

  iex> get_ag_job!(456)
  ** (Ecto.NoResultsError)

  """
  def get_ag_job!(id), do: Repo.get!(AgJob, id)
  def get_ag_job(id), do: Repo.get(AgJob, id)

  @doc """
  Creates a ag_job.

  ## Examples
  iex> create_ag_job(%Sub{...})
  {:ok, %AgJob{}}

  iex> create_ag_job(%{field: value})
  {:ok, %AgJob{}}

  iex> create_ag_job(%{field: bad_value})
  {:error, %Ecto.Changeset{}}

  """
  def create_ag_job(%Sub{} = sub) do
    sub = Repo.preload(sub, reg: [:user])

    dupkey = "#{sub.assignment_id}/#{sub.reg_id}"

    delete_jobs_by_dupkey(dupkey)

    attrs = %{
      sub_id: sub.id,
      dupkey: dupkey,
      prio: count_user_jobs(sub.reg.user_id)
    }

    create_ag_job(attrs)
  end

  def create_ag_job(attrs) do
    %AgJob{}
    |> AgJob.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ag_job.

  ## Examples

      iex> update_ag_job(ag_job, %{field: new_value})
      {:ok, %AgJob{}}

      iex> update_ag_job(ag_job, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ag_job(%AgJob{} = ag_job, attrs) do
    ag_job
    |> AgJob.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an ag_job.

  ## Examples

      iex> delete_ag_job(ag_job)
      {:ok, %AgJob{}}

      iex> delete_ag_job(ag_job)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ag_job(%AgJob{} = ag_job) do
    Repo.delete(ag_job)
  end

  def delete_jobs_by_dupkey(dupkey) do
    Repo.delete_all(
      from(ag in AgJob,
        where: ag.dupkey == ^dupkey
      )
    )
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ag_job changes.

  ## Examples

      iex> change_ag_job(ag_job)
      %Ecto.Changeset{data: %AgJob{}}

  """
  def change_ag_job(%AgJob{} = ag_job, attrs \\ %{}) do
    AgJob.changeset(ag_job, attrs)
  end
end
