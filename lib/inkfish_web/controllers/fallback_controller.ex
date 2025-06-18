defmodule InkfishWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use InkfishWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(InkfishWeb.ChangesetJSON) # Use put_view
    |> render(:error, changeset: changeset) # Use render/2
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(InkfishWeb.ErrorJSON) # Use put_view
    |> render(:not_found) # Use render/2
  end

  # Removed the generic {:error, message} clause as it was specifically added
  # to handle the "We don't delete subs" message, which should no longer be
  # reachable via the API.
end
