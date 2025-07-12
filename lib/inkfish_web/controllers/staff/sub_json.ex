defmodule InkfishWeb.Staff.SubJSON do
  use InkfishWeb, :json

  alias Inkfish.Subs.Sub
  alias InkfishWeb.Staff.RegJSON
  alias InkfishWeb.Staff.TeamJSON
  alias InkfishWeb.Staff.GradeJSON

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
    grades = get_assoc(sub, :grades) || []
    grader = get_assoc(sub, :grader)

    %{
      id: sub.id,
      active: sub.active,
      assignment_id: sub.assignment_id,
      inserted_at: sub.inserted_at,
      reg_id: sub.reg_id,
      reg: RegJSON.data(reg),
      team_id: sub.team_id,
      team: TeamJSON.data(team),
      grades: for(grade <- grades, do: GradeJSON.data(grade)),
      grader_id: sub.grader_id,
      grader: RegJSON.data(grader)
    }
  end
end
