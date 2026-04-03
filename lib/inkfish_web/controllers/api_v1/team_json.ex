defmodule InkfishWeb.ApiV1.TeamJSON do
  use InkfishWeb, :json

  alias Inkfish.Teams.Team

  def data(nil), do: nil

  def data(%Team{} = team) do
    regs = get_assoc(team, :regs) || []

    %{
      id: team.id,
      teamset_id: team.teamset_id,
      active: team.active,
      members: for(reg <- regs, do: member_data(reg))
    }
  end

  defp member_data(reg) do
    user = get_assoc(reg, :user)

    %{
      id: reg.id,
      user_id: reg.user_id,
      name: user && user_display_name(user)
    }
  end
end
