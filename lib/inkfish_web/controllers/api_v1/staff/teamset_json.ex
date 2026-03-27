defmodule InkfishWeb.ApiV1.Staff.TeamsetJSON do
  use InkfishWeb, :json

  alias Inkfish.Teams.Teamset

  def show(%{teamset: teamset}) do
    %{data: data(teamset)}
  end

  defp data(%Teamset{} = teamset) do
    %{
      id: teamset.id,
      name: teamset.name,
      course_id: teamset.course_id
    }
  end
end
