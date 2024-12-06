defmodule Inkfish.Itty.Server do
  use GenServer

  alias Inkfish.Itty.Task

  # How long to stay alive waiting for late
  # subscribers after the process terminates.
  @linger_seconds 300

  def start_link(state0) do
    IO.puts(" =[Itty]= Start server with UUID #{state0.uuid}")
    GenServer.start_link(__MODULE__, state0, name: reg(state0.uuid))
  end

  def reg(uuid) do
    {:via, Registry, {Inkfish.Itty.Reg, uuid}}
  end

  def start(%Task{uuid: uuid, script: script, env: env, on_exit: on_exit}) do
    cookie = Inkfish.Text.gen_uuid()

    env =
      env
      |> Map.update("COOKIE", cookie, & &1)

    state0 = %{
      done: false,
      uuid: uuid,
      cmd: script,
      cookie: cookie,
      env: env,
      on_exit: on_exit
    }

    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [state0]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(Inkfish.Itty.DynSup, spec)
  end

  def peek(uuid) do
    if !Enum.empty?(Registry.lookup(Inkfish.Itty.Reg, uuid)) do
      GenServer.call(reg(uuid), :peek)
    else
      {:error, "No such task"}
    end
  end

  def running?(uuid) do
    if Enum.empty?(Registry.lookup(Inkfish.Itty.Reg, uuid)) do
      false
    else
      {:ok, state} = GenServer.call(reg(uuid), :peek)
      !state.done
    end
  end

  def stop(uuid) do
    if !Enum.empty?(Registry.lookup(Inkfish.Itty.Reg, uuid)) do
      GenServer.call(reg(uuid), :stop)
    else
      :ok
    end
  end

  @impl true
  def init(%{env: env, cmd: cmd, uuid: uuid} = state0) do
    # Start the process
    env =
      System.get_env()
      |> Map.merge(env)
      |> Enum.into([])

    opts = [{:stdout, self()}, {:stderr, self()}, {:env, env}, {:kill_timeout, 3600}, :monitor]

    IO.puts(" =[Itty]= Run cmd [#{cmd}] for UUID #{uuid}")
    {:ok, _pid, ospid} = :exec.run(cmd, opts, 30)

    block = %{seq: 99, stream: :adm, text: "\nStarting task.\n\n"}

    data = %{
      seq: 100,
      blocks: [block],
      ospid: ospid,
      done: false
    }

    {:ok, Map.merge(state0, data)}
  end

  def view(state) do
    outputs =
      [:adm, :out, :err]
      |> Enum.map(fn stream ->
        {stream, get_stream_text(state, stream)}
      end)
      |> Enum.into(%{})

    view =
      state
      |> Map.drop([:on_exit])
      |> Map.put(:outputs, outputs)

    if view.done do
      Map.put(view, :result, get_marked_output(state, state.cookie))
    else
      Map.put(view, :result, nil)
    end
  end

  @impl true
  def handle_call(:peek, _from, state) do
    {:reply, {:ok, view(state)}, state}
  end

  def handle_call(:stop, _from, %{ospid: ospid} = state) do
    send_text("Stopping process early.\n", state)
    :exec.stop(ospid)
    {:reply, :ok, state}
  end

  def send_text(text, %{seq: seq} = state) do
    block = %{seq: seq, stream: :adm, text: text}
    send_block(block, state)
  end

  def send_block(block, %{uuid: uuid, seq: seq, blocks: blocks} = state) do
    blocks = [block | blocks]
    # IO.puts(" =[Itty]= Send block for UUID #{uuid} #{block.seq}")
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "ittys:" <> uuid, {:block, uuid, block})
    {:noreply, %{state | seq: seq + 1, blocks: blocks}}
  end

  @impl true
  def handle_info({:stdout, _, text}, %{seq: seq} = state) do
    block = %{seq: seq, stream: :out, text: text}
    send_block(block, state)
  end

  def handle_info({:stderr, _, text}, %{seq: seq} = state) do
    block = %{seq: seq, stream: :err, text: text}
    send_block(block, state)
  end

  def handle_info({:DOWN, _, _, _, status}, state) do
    %{uuid: uuid, on_exit: on_exit, blocks: blocks} = state

    IO.puts(" =[Itty]= Send done for UUID #{uuid}")
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "ittys:" <> uuid, {:done, uuid})

    if on_exit do
      rv = %{
        uuid: uuid,
        downstat: status,
        status: "ok",
        result: get_marked_output(state, state.cookie),
        log: blocks
      }

      on_exit.(rv)
    end

    Process.send_after(self(), :shutdown, @linger_seconds * 1000)

    {:noreply, %{state | done: true}}
  end

  def handle_info(:shutdown, state0) do
    {:stop, :normal, state0}
  end

  def handle_info(foo, state0) do
    IO.inspect({:info, foo})
    {:noreply, state0}
  end

  def get_stream_text(state, stream) do
    state.blocks
    |> Enum.filter(fn bb -> bb.stream == stream end)
    |> Enum.sort_by(fn bb -> bb.seq end)
    |> Enum.map(fn bb -> bb.text end)
    |> Enum.join("")
  end

  def get_marked_output(state, cookie) do
    splits =
      get_stream_text(state, :out)
      |> String.split("\n#{cookie}\n", trim: true)

    if length(splits) > 1 do
      Enum.at(splits, 1)
    else
      ""
    end
  end
end
