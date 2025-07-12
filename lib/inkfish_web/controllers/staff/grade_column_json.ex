defmodule InkfishWeb.Staff.GradeColumnJson do
  import InkfishWeb.ViewHelpers

  def index(%{grade_columns: grade_columns}) do
    Enum.map(grade_columns, &data(%{grade_column: &1}))
  end

  def show(%{grade_column: nil}), do: nil

  def show(%{grade_column: grade_column}) do
    data(%{grade_column: grade_column})
  end

  def data(%{grade_column: grade_column}) do
    %{
      kind: grade_column.kind
    }
  end
end
