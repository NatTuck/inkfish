defmodule Inkfish.ApiKeysTest do
  use Inkfish.DataCase

  alias Inkfish.ApiKeys

  describe "api_key" do
    alias Inkfish.ApiKeys.ApiKey

    import Inkfish.ApiKeysFixtures

    @invalid_attrs %{key: nil}

    test "list_api_key/0 returns all api_key" do
      api_key = api_key_fixture()
      assert ApiKeys.list_api_key() == [api_key]
    end

    test "get_api_key!/1 returns the api_key with given id" do
      api_key = api_key_fixture()
      assert ApiKeys.get_api_key!(api_key.id) == api_key
    end

    test "create_api_key/1 with valid data creates a api_key" do
      valid_attrs = %{key: "some key"}

      assert {:ok, %ApiKey{} = api_key} = ApiKeys.create_api_key(valid_attrs)
      assert api_key.key == "some key"
    end

    test "create_api_key/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = ApiKeys.create_api_key(@invalid_attrs)
    end

    test "update_api_key/2 with valid data updates the api_key" do
      api_key = api_key_fixture()
      update_attrs = %{key: "some updated key"}

      assert {:ok, %ApiKey{} = api_key} = ApiKeys.update_api_key(api_key, update_attrs)
      assert api_key.key == "some updated key"
    end

    test "update_api_key/2 with invalid data returns error changeset" do
      api_key = api_key_fixture()
      assert {:error, %Ecto.Changeset{}} = ApiKeys.update_api_key(api_key, @invalid_attrs)
      assert api_key == ApiKeys.get_api_key!(api_key.id)
    end

    test "delete_api_key/1 deletes the api_key" do
      api_key = api_key_fixture()
      assert {:ok, %ApiKey{}} = ApiKeys.delete_api_key(api_key)
      assert_raise Ecto.NoResultsError, fn -> ApiKeys.get_api_key!(api_key.id) end
    end

    test "change_api_key/1 returns a api_key changeset" do
      api_key = api_key_fixture()
      assert %Ecto.Changeset{} = ApiKeys.change_api_key(api_key)
    end
  end
end
