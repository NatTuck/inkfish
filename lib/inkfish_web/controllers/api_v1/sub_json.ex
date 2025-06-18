defmodule InkfishWeb.ApiV1.SubJSON do
  alias Inkfish.Subs.Sub

  @doc """
  Renders a list of subs.
  """
  def index(%{subs: subs}) do
    %{data: for(sub <- subs, do: data(sub))}
  end

  @doc """
  Renders a single sub.
  """
  def show(%{sub: sub}) do
    %{data: data(sub)}
  end

  defp data(%Sub{} = sub) do
    %{
      id: sub.id,
      active: sub.active,
      late_penalty: sub.late_penalty,
      score: sub.score,
      hours_spent: sub.hours_spent,
      note: sub.note,
      ignore_late_penalty: sub.ignore_late_penalty
    }
  end
end
