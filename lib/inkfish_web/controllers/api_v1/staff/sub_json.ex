defmodule InkfishWeb.ApiV1.Staff.SubJSON do
  use InkfishWeb, :json

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
  def show(%{sub: nil}), do: %{data: nil}

  def show(%{sub: sub}) do
    %{data: data(sub)}
  end

  def data(nil), do: nil

  def data(%Sub{} = sub) do
    reg = get_assoc(sub, :reg)

    %{
      id: sub.id,
      active: sub.active,
      late_penalty: sub.late_penalty,
      score: sub.score,
      hours_spent: sub.hours_spent,
      note: sub.note,
      ignore_late_penalty: sub.ignore_late_penalty,
      upload: Inkfish.Uploads.Upload.upload_url(sub.upload),
      reg: InkfishWeb.Staff.RegJSON.data(reg)
    }
  end
end
