defmodule Inkfish.Subs.ActiveSub do
  @moduledoc """
  Tracks which submission is active for each student (reg) per assignment.

  Each {reg_id, assignment_id} pair has exactly one active_sub pointing
  to the submission that represents the student's current work.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Inkfish.Users.Reg
  alias Inkfish.Assignments.Assignment
  alias Inkfish.Subs.Sub

  @timestamps_opts [
    type: :utc_datetime,
    autogenerate: {Inkfish.LocalTime, :now_utc, []}
  ]

  schema "active_subs" do
    belongs_to :reg, Reg
    belongs_to :assignment, Assignment
    belongs_to :sub, Sub

    timestamps()
  end

  @doc """
  Changeset for creating or updating an active_sub.
  """
  def changeset(active_sub, attrs) do
    active_sub
    |> cast(attrs, [:reg_id, :assignment_id, :sub_id])
    |> validate_required([:reg_id, :assignment_id, :sub_id])
    |> foreign_key_constraint(:reg_id)
    |> foreign_key_constraint(:assignment_id)
    |> foreign_key_constraint(:sub_id)
    |> unique_constraint([:reg_id, :assignment_id])
  end
end
