defmodule InkfishWeb.Staff.TeamMemberJson do
  use InkfishWeb.Json

  def index(%{team_members: team_members}) do
    %{data: Enum.map(team_members, &data(%{team_member: &1}))}
  end

  def show(%{team_member: team_member}) do
    %{data: data(%{team_member: team_member})}
  end

  def data(%{team_member: team_member}) do
    %{id: team_member.id}
  end
end
