defmodule InkfishWeb.JsonHelpers do
  def get_assoc(item, field) do
    data = Map.get(item, field)

    if Ecto.assoc_loaded?(data) do
      data
    else
      nil
    end
  end
end
