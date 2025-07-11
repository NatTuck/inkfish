defmodule InkfishWeb.Staff.GradeColumnJson do
  use InkfishWeb.ViewHelpers

  def data(%{grade_column: grade_column}) do
    %{
      kind: grade_column.kind
    }
  end
end
