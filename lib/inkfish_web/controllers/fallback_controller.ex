defmodule InkfishWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use InkfishWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(InkfishWeb.ChangesetJSON, :error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> render(InkfishWeb.ErrorJSON, :not_found)
  end

  # Removed the generic {:error, message} clause as it was specifically added
  # to handle the "We don't delete subs" message, which should no longer be
  # reachable via the API.
end
