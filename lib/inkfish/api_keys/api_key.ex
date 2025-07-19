defmodule Inkfish.ApiKeys.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset
  alias Inkfish.Users.User

  schema "api_keys" do
    field(:key, :string)
    field(:name, :string)
    belongs_to(:user, User)

    timestamps(type: :utc_datetime)
  end

  def parent(), do: :user

  @doc false
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :key, :user_id])
    |> validate_required([:name, :key, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
