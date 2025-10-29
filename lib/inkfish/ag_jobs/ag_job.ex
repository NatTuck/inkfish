defmodule Inkfish.AgJobs.AgJob do
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__

  schema "ag_jobs" do
    field(:uuid, :string)
    field(:started_at, :utc_datetime)
    field(:finished_at, :utc_datetime)
    field(:dupkey, :string)
    field(:prio, :integer)
    belongs_to(:sub, Inkfish.Subs.Sub)

    timestamps(type: :utc_datetime)
  end

  def parent(), do: :sub

  @doc false
  def changeset(ag_job, attrs) do
    ag_job
    |> cast(attrs, [:dupkey, :prio, :sub_id, :started_at, :finished_at, :uuid])
    |> validate_required([:dupkey, :prio, :sub_id, :uuid])
  end

  def ag_job_status(%AgJob{} = job) do
    cond do
      is_nil(job.started_at) && is_nil(job.finished_at) ->
        :ready

      !is_nil(job.started_at) && is_nil(job.finished_at) ->
        :running

      !is_nil(job.started_at) && !is_nil(job.finished_at) ->
        :done

      is_nil(job.started_at) && !is_nil(job.finished_at) ->
        :borked
    end
  end
end
