defmodule InkfishWeb.TeamJSON do
  use InkfishWeb, :json

  alias Inkfish.Teams.Team
  alias InkfishWeb.RegJSON
  alias InkfishWeb.SubJSON

  def index(%{teams: teams}) do
    %{data: for(team <- teams, do: data(team))}
  end

  def show(%{team: nil}), do: %{data: nil}

  def show(%{team: team}) do
    %{data: data(team)}
  end

  def data(nil), do: nil

  def data(%Team{} = team) do
    regs = get_assoc(team, :regs) || []
    subs = get_assoc(team, :subs) || []

    %{
      id: team.id,
      active: team.active,
      regs: for(reg <- regs, do: RegJSON.data(reg)),
      subs: for(sub <- subs, do: SubJSON.data(sub))
    }
  end
end
