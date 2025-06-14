defmodule Inkfish.ApiKeysFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Inkfish.ApiKeys` context.
  """

  @doc """
  Generate a api_key.
  """
  def api_key_fixture(attrs \\ %{}) do
    {:ok, api_key} =
      attrs
      |> Enum.into(%{
        key: "some key"
      })
      |> Inkfish.ApiKeys.create_api_key()

    api_key
  end
end
