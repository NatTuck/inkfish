defmodule InkfishWeb.Staff.TeamMemberJSON do
  use InkfishWeb, :json

  alias Inkfish.Teams.TeamMember

  def index(%{team_members: team_members}) do
    %{data: for(team_member <- team_members, do: data(team_member))}
  end

  def show(%{team_member: nil}), do: %{data: nil}

  def show(%{team_member: team_member}) do
    %{data: data(team_member)}
  end

  def data(nil), do: nil

  def data(%TeamMember{} = team_member) do
    %{id: team_member.id}
  end
end
