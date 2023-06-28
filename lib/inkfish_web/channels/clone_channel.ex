defmodule InkfishWeb.CloneChannel do
  use InkfishWeb, :channel

  alias Inkfish.Uploads.Git
  alias Inkfish.Itty

  def join("clone:" <> nonce, %{"token" => token}, socket) do
    case Phoenix.Token.verify(InkfishWeb.Endpoint, "upload", token, max_age: 8640) do
      {:ok, %{kind: kind, nonce: ^nonce}} ->
        socket = socket
        |> assign(:kind, kind)
        |> assign(:upload_id, nil)
        {:ok, socket}
      failure ->
        IO.inspect(failure)
        {:error, %{reason: "unauthorized"}}
    end
  end

  def got_exit(socket) do
    {:ok, results} = Git.get_results(socket.assigns[:uuid])

    {:ok, upload} = Git.create_upload(
		      results,
		      socket.assigns[:kind],
		      socket.assigns[:user_id])
    upinfo = %{
      "id" => upload.id,
      "name" => upload.name,
      "size" => upload.size,
    }
    socket = assign(socket, :upload, upinfo)

    data = %{
      status: "normal",
      results: results,
      upload: socket.assigns[:upload],
    }

    IO.inspect {:got_exit, results, data, socket.assigns}

    push(socket, "done", data)
  end

  def handle_in("clone", %{"url" => url}, socket) do
    {:ok, uuid} = Git.start_clone(url)
    case Itty.open(uuid) do
      {:ok, state} ->
	socket = socket
	|> assign(:uuid, uuid)
	|> assign(:itty, state)
	|> assign(:blocks, state.blocks)
	|> assign(:done, state.done)

	Enum.each state.blocks, fn item ->
	  push(socket, "block", item)
	end

	if state.done do
	  got_exit(socket)
	end

	{:reply, :ok, socket}
      _else ->
	{:reply, {:error, %{reason: "bad itty"}}}
    end
  end

  def handle_info({:block, _uuid, item}, socket) do
    #IO.inspect {:block, item}
    push(socket, "block", item)
    {:noreply, socket}
  end

  def handle_info({:done, uuid}, socket) do
    IO.inspect {:clone_channel, :done, uuid}
    push(socket, "done", %{uuid: uuid})
    got_exit(socket)
    {:noreply, socket}
  end
end
