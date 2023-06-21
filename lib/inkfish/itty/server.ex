defmodule Inkfish.Itty.Server do
  use GenServer

  # How long to stay alive waiting for late
  # subscribers after the process terminates.
  @linger_seconds 120
  
  def start_link(state0) do
    GenServer.start_link(__MODULE__, state0, name: reg(state0.uuid))
  end

  def reg(uuid) do
    {:via, Registry, {Inkfish.Itty.Reg, uuid}}
  end

  def start(uuid, cmd, env, on_exit) do
    cookie = Inkfish.Text.gen_uuid()
    env = env
    |> Map.update("COOKIE", cookie, &(&1))
    state0 = %{
      uuid: uuid,
      cmd: cmd,
      cookie: cookie,
      env: env,
      on_exit: on_exit,
    }
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [state0]},
      restart: :temporary,
    }
    DynamicSupervisor.start_child(Inkfish.Itty.DynSup, spec)
  end

  def peek(uuid) do
    if !Enum.empty?(Registry.lookup(Inkfish.Itty.Reg, uuid)) do
      GenServer.call(reg(uuid), :peek)
    else
      {:error, "unknown"}
    end 
  end

  @impl true
  def init(%{cmd: cmd, uuid: uuid, env: env} = state0) do
    env = System.get_env()
    |> Map.merge(env)
    |> Enum.into([])

    IO.inspect({:run, cmd, Enum.with_index(env)}, limit: :infinity)

    opts = [{:stdout, self()}, {:stderr, self()}, {:env, env},
	    {:kill_timeout, 5}, :monitor]
    {:ok, _pid, _ospid} = :exec.run(cmd, opts, 30)
    {:ok, Map.merge(state0, %{seq: 0, blocks: [], done: false})}
  end

  @impl true
  def handle_call(:peek, _from, state) do
    {:reply, {:ok, view(state)}, state}
  end

  def view(state) do
    Map.drop(state, [:on_exit])
  end

  @impl true
  def handle_info({:stdout, _, text}, %{uuid: uuid, seq: seq, blocks: blocks} = state) do
    block = %{seq: seq, stream: :out, text: text}
    blocks = [block | blocks]
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "ittys:" <> uuid, {:block, uuid, block})
    {:noreply, %{state | seq: seq + 1, blocks: blocks}}
  end

  def handle_info({:stderr, _, text}, %{uuid: uuid, seq: seq, blocks: blocks} = state) do
    block = %{seq: seq, stream: :err, text: text} 
    blocks = [block | blocks]
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "ittys:" <> uuid, {:block, uuid, block})
    {:noreply, %{state | seq: seq + 1, blocks: blocks}}
  end

  def handle_info({:DOWN, _, _, _, status}, state) do
    %{uuid: uuid, on_exit: on_exit} = state

    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "ittys:" <> uuid, {:done, uuid})

    if on_exit do
      state
      |> get_marked_output(state.cookie)
      |> on_exit.()
    end

    Process.send_after(self(), :shutdown, @linger_seconds * 1000)

    {:noreply, %{state | done: true}}
  end

  def handle_info(:shutdown, state0) do
    {:stop, :normal, state0}
  end

  def handle_info(foo, state0) do
    IO.inspect {:info, foo}
    {:noreply, state0}
  end

  def get_marked_output(state, cookie) do
    splits = state.blocks
    |> Enum.filter(fn bb -> bb.stream == :out end)
    |> Enum.sort_by(fn bb -> bb.seq end)
    |> Enum.map(fn bb -> bb.text end)
    |> Enum.join("")
    |> String.split("\n#{cookie}\n", trim: true)

    if length(splits) > 1 do
      Enum.at(splits, 1)
    else
      ""
    end
  end
end
