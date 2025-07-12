defmodule InkfishWeb.GradeColumnJson do
  def show(%{grade_column: gc}) do
    %{
      kind: gc.kind,
      name: gc.name,
      base: gc.base,
      points: gc.points
    }
  end
end
