defmodule InkfishWeb.Staff.SubJson do
  use InkfishWeb.Json
  alias InkfishWeb.Staff.RegJson
  alias InkfishWeb.Staff.TeamJson
  alias InkfishWeb.Staff.GradeJson

  def index(%{subs: subs}) do
    %{data: Enum.map(subs, &data(%{sub: &1}))}
  end

  def show(%{sub: nil}), do: nil

  def show(%{sub: sub}) do
    %{data: data(%{sub: sub})}
  end

  def data(%{sub: sub}) do
    reg = get_assoc(sub, :reg)
    team = get_assoc(sub, :team)
    grades = get_assoc(sub, :grades) || []
    grader = get_assoc(sub, :grader)

    %{
      id: sub.id,
      active: sub.active,
      assignment_id: sub.assignment_id,
      inserted_at: sub.inserted_at,
      reg_id: sub.reg_id,
      reg: RegJson.show(%{reg: reg}),
      team_id: sub.team_id,
      team: TeamJson.show(%{team: team}),
      grades: GradeJson.index(%{grades: grades}),
      grader_id: sub.grader_id,
      grader: RegJson.show(%{reg: grader})
    }
  end
end
