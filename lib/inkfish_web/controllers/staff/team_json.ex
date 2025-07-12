defmodule InkfishWeb.Staff.TeamJson do
  use InkfishWeb.ViewHelpers

  alias Inkfish.Teams.Team
  alias InkfishWeb.Staff.RegJson
  alias InkfishWeb.Staff.TeamsetJson
  alias InkfishWeb.Staff.SubJson
  alias InkfishWeb.CoreComponents

  def index(%{teams: teams}) do
    %{data: Enum.map(teams, &data(%{team: &1}))}
  end

  def show(%{team: nil}), do: nil

  def show(%{team: team}) do
    %{data: data(%{team: team})}
  end

  def data(%{team: %Team{} = team}) do
    regs = get_assoc(team, :regs) || []
    teamset = get_assoc(team, :teamset)
    subs = get_assoc(team, :subs) || []

    %{
      id: team.id,
      active: team.active,
      regs: RegJson.index(%{regs: regs}),
      teamset: TeamsetJson.show(%{teamset: teamset}),
      subs: SubJson.index(%{subs: subs})
    }
  end

  def view_members(%Team{} = team) do
    %{
      id: team.id,
      users:
        Enum.map(team.regs, fn reg ->
          user = reg.user
          %{id: user.id, name: CoreComponents.user_display_name(user)}
        end)
    }
  end
end
