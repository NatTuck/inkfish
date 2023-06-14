defmodule Inkfish.Terms.Server do
  use GenServer

  def start_link(uuid, cmd) do
    GenServer.start_link(__MODULE__, %{uuid: uuid, cmd: cmd}, name: reg(uuid))
  end

  def reg(uuid) do
    {:via, Registry, {Inkfish.Terms.Reg, uuid}}
  end

  def start(uuid, cmd) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [uuid, cmd]},
      restart: :temporary,
    }
    DynamicSupervisor.start_child(Inkfish.Terms.DynSup, spec)
  end

  def peek(uuid) do
    if !Enum.empty?(Registry.lookup(Inkfish.Terms.Reg, uuid)) do
      GenServer.call(reg(uuid), :peek)
    else
      {:error, "unknown"}
    end 
  end

  @impl true
  def init(%{cmd: cmd, uuid: uuid}) do
    IO.inspect {:run, cmd}
    opts = [{:stdout, self()}, {:stderr, self()}, {:kill_timeout, 5}, :monitor]
    {:ok, _pid, _ospid} = :exec.run(cmd, opts, 30)
    {:ok, %{cmd: cmd, uuid: uuid, seq: 0, blocks: []}}
  end

  @impl true
  def handle_call(:peek, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_info({:stdout, _, text}, %{uuid: uuid, seq: seq, blocks: blocks} = state) do
    block = %{seq: seq, stream: :out, text: text}
    blocks = [block | blocks]
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "terms:" <> uuid, {:block, uuid, block})
    {:noreply, %{state | seq: seq + 1, blocks: blocks}}
  end

  def handle_info({:stderr, _, text}, %{uuid: uuid, seq: seq, blocks: blocks} = state) do
    block = %{seq: seq, stream: :err, text: text} 
    blocks = [block | blocks]
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "terms:" <> uuid, {:block, uuid, block})
    {:noreply, %{state | seq: seq + 1, blocks: blocks}}
  end

  def handle_info({:DOWN, _, _, _, status}, state) do
    uuid = state.uuid
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "terms:" <> uuid, {:done, uuid})
    {:noreply, state}
  end

  def handle_info(foo, state0) do
    IO.inspect {:info, foo}
    {:noreply, state0}
  end
end
