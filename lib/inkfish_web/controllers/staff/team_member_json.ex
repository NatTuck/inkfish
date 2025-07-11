defmodule InkfishWeb.Staff.TeamMemberJson do
  use InkfishWeb.ViewHelpers
  alias InkfishWeb.Staff.TeamMemberView

  def index(%{team_members: team_members}) do
    %{data: render_many(team_members, TeamMemberView, "team_member.json")}
  end

  def show(%{team_member: team_member}) do
    %{data: render_one(team_member, TeamMemberView, "team_member.json")}
  end

  def data(%{team_member: team_member}) do
    %{id: team_member.id}
  end
end
