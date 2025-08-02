defmodule InkfishWeb.ApiV1.Staff.GradeJSON do
  alias Inkfish.Grades.Grade

  @doc """
  Renders a list of grades.
  """
  def index(%{grades: grades}) do
    %{data: for(grade <- grades, do: data(grade))}
  end

  @doc """
  Renders a single grade.
  """
  def show(%{grade: grade}) do
    %{data: data(grade)}
  end

  defp data(%Grade{} = grade) do
    %{
      id: grade.id,
      score: grade.score,
      log_uuid: grade.log_uuid
    }
  end
end
