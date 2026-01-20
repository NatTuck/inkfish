defmodule Inkfish.ApiKeysTest do
  use Inkfish.DataCase

  alias Inkfish.ApiKeys
  alias Inkfish.ApiKeys.ApiKey
  import Inkfish.Factory

  @invalid_attrs %{"key" => nil}

  describe "api_keys" do
    test "list_user_apikeys/1 returns all api_keys for a user" do
      user = insert(:user)
      api_key1 = insert(:api_key, user: user)
      api_key2 = insert(:api_key, user: user)
      # for other user
      insert(:api_key)

      found_keys =
        ApiKeys.list_user_apikeys(user)
        |> Enum.map(& &1.id)
        |> Enum.sort()

      expected_keys = Enum.sort([api_key1.id, api_key2.id])

      assert found_keys == expected_keys
    end

    test "get_api_key!/1 returns the api_key with given id" do
      api_key = insert(:api_key)
      fetched_key = ApiKeys.get_api_key!(api_key.id)

      # We can't compare the structs directly because the factory-inserted
      # struct will have virtual password fields on its user association,
      # while the one fetched from the DB will not.
      assert fetched_key.id == api_key.id
      assert fetched_key.name == api_key.name
      assert fetched_key.key == api_key.key
      assert fetched_key.user_id == api_key.user_id
    end

    test "create_api_key/2 with valid data creates an api_key" do
      user = insert(:user)
      valid_attrs = %{"name" => "some name", "key" => "some key"}

      assert {:ok, %ApiKey{} = api_key} =
               ApiKeys.create_api_key(user, valid_attrs)

      assert api_key.name == "some name"
      assert api_key.key == "some key"
      assert api_key.user_id == user.id
    end

    test "create_api_key/2 with invalid data returns error changeset" do
      user = insert(:user)

      assert {:error, %Ecto.Changeset{}} =
               ApiKeys.create_api_key(user, @invalid_attrs)
    end

    test "update_api_key/2 with valid data updates the api_key" do
      api_key = insert(:api_key)
      update_attrs = %{"key" => "some updated key"}

      assert {:ok, %ApiKey{} = api_key} =
               ApiKeys.update_api_key(api_key, update_attrs)

      assert api_key.key == "some updated key"
    end

    test "update_api_key/2 with invalid data returns error changeset" do
      api_key = insert(:api_key)

      assert {:error, %Ecto.Changeset{}} =
               ApiKeys.update_api_key(api_key, @invalid_attrs)

      fresh_api_key = ApiKeys.get_api_key!(api_key.id)
      assert api_key.key == fresh_api_key.key
    end

    test "delete_api_key/1 deletes the api_key" do
      api_key = insert(:api_key)
      assert {:ok, %ApiKey{}} = ApiKeys.delete_api_key(api_key)

      assert_raise Ecto.NoResultsError, fn ->
        ApiKeys.get_api_key!(api_key.id)
      end
    end

    test "change_api_key/1 returns an api_key changeset" do
      api_key = insert(:api_key)
      assert %Ecto.Changeset{} = ApiKeys.change_api_key(api_key)
    end
  end
end
