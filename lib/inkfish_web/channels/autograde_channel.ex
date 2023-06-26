defmodule InkfishWeb.AutogradeChannel do
  use InkfishWeb, :channel

  alias Inkfish.Grades

  def join("autograde:" <> uuid, %{"token" => token}, socket) do
    case Phoenix.Token.verify(InkfishWeb.Endpoint, "autograde", token, max_age: 8640) do
      {:ok, %{uuid: ^uuid}} ->
        socket = socket
        |> assign(:uuid, uuid)

	Process.send_after(self(), :open, 1)

        {:ok, %{blocks: []}, socket}
      failure ->
        IO.inspect(failure)
        {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(:open, socket) do
    uuid = socket.assigns[:uuid]
    case Inkfish.Itty.open(uuid) do
      {:ok, %{blocks: blocks, done: done}} ->
	Enum.each blocks, fn block ->
	  push(socket, "block", block)
	end

        if done do
          Process.send_after(self(), {:done, uuid}, 1)
        end
      {:error, _} ->
	grade = Grades.get_grade_by_log_uuid(uuid)
	|> Grades.preload_sub_and_upload()
	
	if grade do
	  log = Grades.Grade.get_log(grade)
	  push(socket, "block", %{seq: 10, stream: :err, text: "itty missing\n" })
	  push(socket, "block", %{seq: 11, stream: :out, text: Jason.encode!(log)})
	else
	  push(socket, "block", %{seq: 10, stream: :err, text: "itty missing\n" })
	end

	Process.send_after(self(), {:done, uuid}, 1)
    end

    {:noreply, socket}
  end

  def handle_info(:show_score, socket) do
    grade = Grades.get_grade_by_log_uuid(socket.assigns[:uuid])
    if grade do
      data = %{
        serial: 8_000_000_001,
        stream: "stderr",
        text: "\n\nyour score: #{grade.score} / #{grade.grade_column.points}",
      }
      push(socket, "output", data)
    else
      data = %{
        serial: 8_000_000_001,
        stream: "stderr",
        text: "\n\ncan't find grade to see score",
      }
      push(socket, "output", data)
    end

    {:noreply, socket}
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
