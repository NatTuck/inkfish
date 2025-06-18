defmodule Inkfish.ApiKeysFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Inkfish.ApiKeys` context.
  """
  import Inkfish.Factory

  @doc """
  Generate an API key.
  """
  def api_key_fixture(attrs \\ %{}) do
    # Use insert(:user) from Inkfish.Factory instead of user_fixture()
    user = Map.get(attrs, :user, insert(:user))

    attrs =
      Enum.into(attrs, %{
        key: "some key #{System.unique_integer()}"
      })

    {:ok, api_key} = Inkfish.ApiKeys.create_api_key(user, attrs)

    api_key
  end
end
