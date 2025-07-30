defmodule Inkfish.AgJobs.AgJob do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ag_jobs" do
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
    |> cast(attrs, [:dupkey, :prio, :sub_id, :started_at, :finished_at])
    |> validate_required([:dupkey, :prio, :sub_id])
  end
end
