defmodule InkfishWeb.ApiV1.SubJSON do
  use InkfishWeb, :json

  alias Inkfish.Subs.Sub
  alias Inkfish.Uploads.Upload

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
    upload = get_assoc(sub, :upload)

    %{
      id: sub.id,
      active: sub.active,
      late_penalty: sub.late_penalty,
      score: sub.score,
      hours_spent: sub.hours_spent,
      note: sub.note,
      ignore_late_penalty: sub.ignore_late_penalty,
      upload: Upload.upload_url(upload)
    }
  end
end
