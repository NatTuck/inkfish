defmodule InkfishWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use InkfishWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    # Use put_view
    |> put_view(InkfishWeb.ChangesetJSON)
    # Use render/2
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    # Use put_view
    |> put_view(InkfishWeb.ErrorJSON)
    # Use render/2
    |> render(:not_found)
  end

  # Handle ArgumentError (e.g., from String.to_integer for invalid IDs)
  def call(conn, {:error, %ArgumentError{message: message}}) do
    conn
    |> put_status(:bad_request)
    |> put_view(InkfishWeb.ErrorJSON)
    |> render(:error, message: message)
  end

  def call(conn, :error) do
    conn
    |> put_status(:bad_request)
    |> put_view(InkfishWeb.ErrorJSON)
    |> render(:error, message: "Bad request")
  end
end
