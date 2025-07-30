defmodule Inkfish.Teams.TeamMember do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]

  schema "team_members" do
    belongs_to :team, Inkfish.Teams.Team
    belongs_to :reg, Inkfish.Users.Reg

    timestamps()
  end

  def parent(), do: :team

  @doc false
  def changeset(team_member, attrs) do
    team_member
    |> cast(attrs, [:team_id, :reg_id])
    |> validate_required([:team_id, :reg_id])
    |> foreign_key_constraint(:team_id)
    |> foreign_key_constraint(:reg_id)
  end
end
