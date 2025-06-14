defmodule Inkfish.ApiKeys.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_key" do
    field :key, :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:key])
    |> validate_required([:key])
  end
end
