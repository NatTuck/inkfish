defmodule Inkfish.ApiKeys.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset
  alias Inkfish.Users.User

  schema "api_keys" do
    field :key, :string
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:key, :user_id])
    |> validate_required([:key, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
