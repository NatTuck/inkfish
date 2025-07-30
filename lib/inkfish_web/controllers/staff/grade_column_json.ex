defmodule InkfishWeb.Staff.GradeColumnJSON do
  use InkfishWeb, :json

  alias Inkfish.Grades.GradeColumn

  def index(%{grade_columns: grade_columns}) do
    %{data: for(gc <- grade_columns, do: data(gc))}
  end

  def show(%{grade_column: nil}), do: %{data: nil}

  def show(%{grade_column: grade_column}) do
    %{data: data(grade_column)}
  end

  def data(nil), do: nil

  def data(%GradeColumn{} = grade_column) do
    %{
      id: grade_column.id,
      name: grade_column.name,
      kind: grade_column.kind,
      points: grade_column.points
    }
  end
end
