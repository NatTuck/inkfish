defmodule InkfishWeb.IttyChannel do
  use InkfishWeb, :channel

  alias Inkfish.Terms

  @impl true
  def join("itty:" <> uuid, _payload, socket) do
    if authorized?(socket) do
      case Terms.open(uuid) do
	{:ok, state} ->
	  socket = socket
	  |> assign(:uuid, uuid)
	  |> assign(:term, state)
	  |> assign(:blocks, state.blocks)
	  {:ok, state, socket}
	_else ->
	  {:error, %{reason: "bad itty"}}
      end
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  defp authorized?(socket) do
    user = Inkfish.Users.get_user(socket.assigns[:user_id])
    user && user.is_admin
  end

  def handle_info({:block, _uuid, item}, socket) do
    IO.inspect {:block, item}
    push(socket, "block", item)
    {:noreply, socket}
  end

  def handle_info({:done, uuid}, socket) do
    IO.inspect {:done, uuid}
    push(socket, "done", %{uuid: uuid})
    {:noreply, socket}
  end
end
