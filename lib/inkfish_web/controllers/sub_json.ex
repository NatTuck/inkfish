defmodule InkfishWeb.SubJSON do
  use InkfishWeb, :json

  alias Inkfish.Subs.Sub
  alias InkfishWeb.RegJSON
  alias InkfishWeb.TeamJSON

  def index(%{subs: subs}) do
    %{data: for(sub <- subs, do: data(sub))}
  end

  def show(%{sub: nil}), do: %{data: nil}

  def show(%{sub: sub}) do
    %{data: data(sub)}
  end

  def data(nil), do: nil

  def data(%Sub{} = sub) do
    reg = get_assoc(sub, :reg)
    team = get_assoc(sub, :team)

    # Check if active_sub is loaded and present
    active =
      case sub.active_sub do
        %Ecto.Association.NotLoaded{} -> false
        nil -> false
        _ -> true
      end

    %{
      id: sub.id,
      active: active,
      assignment_id: sub.assignment_id,
      inserted_at: sub.inserted_at,
      reg_id: sub.reg_id,
      reg: RegJSON.data(reg),
      team_id: sub.team_id,
      team: TeamJSON.data(team)
    }
  end
end
