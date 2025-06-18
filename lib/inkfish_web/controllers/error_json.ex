defmodule InkfishWeb.ErrorJSON do
  def not_found(_assigns) do
    %{errors: %{detail: "Not Found"}}
  end

  # This function is used by the SubController's index action when assignment_id is missing.
  # It's also implicitly used by ChangesetJSON for general errors.
  def error(%{message: message}) do
    %{error: message}
  end
end
