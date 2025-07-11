defmodule InkfishWeb.Staff.TeamJson do
  use InkfishWeb.ViewHelpers

  alias Inkfish.Teams.Team
  alias InkfishWeb.Staff.TeamView

  def index(%{teams: teams}) do
    %{data: render_many(teams, TeamView, "team.json")}
  end

  def show(%{team: team}) do
    %{data: render_one(team, TeamView, "team.json")}
  end

  def data(%{team: %Team{} = team}) do
    regs = get_assoc(team, :regs) || []
    teamset = get_assoc(team, :teamset)
    subs = get_assoc(team, :subs) || []

    %{
      id: team.id,
      active: team.active,
      regs: render_many(regs, InkfishWeb.Staff.RegView, "reg.json"),
      teamset:
        render_one(teamset, InkfishWeb.Staff.TeamsetView, "teamset.json"),
      subs: render_many(subs, InkfishWeb.Staff.SubView, "sub.json")
    }
  end

  alias InkfishWeb.ViewHelpers

  def view_members(%Team{} = team) do
    %{
      id: team.id,
      users:
        Enum.map(team.regs, fn reg ->
          user = reg.user
          %{id: user.id, name: ViewHelpers.user_display_name(user)}
        end)
    }
  end
end
