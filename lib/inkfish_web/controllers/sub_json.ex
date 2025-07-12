defmodule InkfishWeb.SubJSON do
  import InkfishWeb.ViewHelpers

  def show(%{sub: sub}) do
    reg = get_assoc(sub, :reg)
    team = get_assoc(sub, :team)

    %{
      active: sub.active,
      assignment_id: sub.assignment_id,
      inserted_at: sub.inserted_at,
      reg_id: sub.reg_id,
      reg: InkfishWeb.RegView.show(reg),
      team_id: sub.team_id,
      team: InkfishWeb.TeamView.show(team)
    }
  end
end
