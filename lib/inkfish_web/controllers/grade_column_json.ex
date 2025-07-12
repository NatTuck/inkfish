defmodule InkfishWeb.GradeColumnJSON do
  use InkfishWeb, :json

  alias Inkfish.Grades.GradeColumn

  def index(%{grade_columns: grade_columns}) do
    %{data: for(gc <- grade_columns, do: data(gc))}
  end

  def show(%{grade_column: nil}), do: %{data: nil}

  def show(%{grade_column: gc}) do
    %{data: data(gc)}
  end

  def data(nil), do: nil

  def data(%GradeColumn{} = gc) do
    %{
      id: gc.id,
      kind: gc.kind,
      name: gc.name,
      base: gc.base,
      points: gc.points
    }
  end
end
