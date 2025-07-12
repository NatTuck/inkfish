defmodule InkfishWeb.TeamJSON do
  import InkfishWeb.ViewHelpers

  alias Inkfish.Teams.Team

  def show(%{team: %Team{} = team}) do
    regs = get_assoc(team, :regs) || []
    subs = get_assoc(team, :subs) || []

    %{
      id: team.id,
      active: team.active,
      regs: InkfishWeb.RegView.index(%{regs: regs}),
      subs: InkfishWeb.SubView.index(%{subs: subs})
    }
  end
end
