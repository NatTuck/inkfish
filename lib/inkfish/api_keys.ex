defmodule Inkfish.ApiKeys do
  @moduledoc """
  The ApiKeys context.
  """

  import Ecto.Query, warn: false
  alias Inkfish.Repo

  alias Inkfish.ApiKeys.ApiKey

  @doc """
  Returns the list of api_key.

  ## Examples

      iex> list_api_key()
      [%ApiKey{}, ...]

  """
  def list_api_key do
    Repo.all(ApiKey)
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

  @doc """
  Creates a api_key.

  ## Examples

      iex> create_api_key(%{field: value})
      {:ok, %ApiKey{}}

      iex> create_api_key(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_api_key(attrs \\ %{}) do
    %ApiKey{}
    |> ApiKey.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a api_key.

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
  end

  @doc """
  Deletes a api_key.

  ## Examples

      iex> delete_api_key(api_key)
      {:ok, %ApiKey{}}

      iex> delete_api_key(api_key)
      {:error, %Ecto.Changeset{}}

  """
  def delete_api_key(%ApiKey{} = api_key) do
    Repo.delete(api_key)
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
