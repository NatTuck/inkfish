defmodule Inkfish.ApiKeys do
  @moduledoc """
  The ApiKeys context.
  """

  import Ecto.Query, warn: false
  alias Inkfish.Repo

  alias Inkfish.ApiKeys.ApiKey
  alias Inkfish.Users.User

  @doc """
  Returns the list of API keys for a user.

  ## Examples

      iex> list_user_apikeys(user)
      [%ApiKey{}, ...]

  """
  def list_user_apikeys(%User{} = user) do
    Repo.all(
      from(k in ApiKey,
        where: k.user_id == ^user.id,
        order_by: [desc: k.inserted_at]
      )
    )
  end

  @doc """
  Gets a single api_key.

  Raises `Ecto.NoResultsError` if the Api key does not exist.

  ## Examples

      iex> get_api_key!(123)
      %ApiKey{}

      iex> get_api_key!(456)
      ** (Ecto.NoResultsError)

  """
  def get_api_key!(id), do: Repo.get!(ApiKey, id)

  def get_user_by_api_key(key) do
    key =
      Repo.get_by(ApiKey, key: key)
      |> Repo.preload(:user)

    if key do
      {:ok, key.user}
    else
      {:error, "Bad API key."}
    end
  end

  @doc """
  Creates an API key for a user.

  ## Examples

      iex> create_api_key(user, %{field: value})
      {:ok, %ApiKey{}}

      iex> create_api_key(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_api_key(%User{} = user, attrs \\ %{}) do
    keys = list_user_apikeys(user)

    if length(keys) < 10 do
      %ApiKey{}
      |> ApiKey.changeset(Map.put(attrs, "user_id", user.id))
      |> Repo.insert()
    else
      {:error, "Too many api keys"}
    end
  end

  @doc """
  Updates an api_key.

  ## Examples

      iex> update_api_key(api_key, %{field: new_value})
      {:ok, %ApiKey{}}

      iex> update_api_key(api_key, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_api_key(%ApiKey{} = api_key, attrs) do
    api_key
    |> ApiKey.changeset(attrs)
    |> Repo.update()
    |> Repo.Cache.updated()
  end

  @doc """
  Deletes an api_key.

  ## Examples

      iex> delete_api_key(api_key)
      {:ok, %ApiKey{}}

      iex> delete_api_key(api_key)
      {:error, %Ecto.Changeset{}}

  """
  def delete_api_key(%ApiKey{} = api_key) do
    Repo.delete(api_key)
    |> Repo.Cache.updated()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking api_key changes.

  ## Examples

      iex> change_api_key(api_key)
      %Ecto.Changeset{data: %ApiKey{}}

  """
  def change_api_key(%ApiKey{} = api_key, attrs \\ %{}) do
    ApiKey.changeset(api_key, attrs)
  end
end
