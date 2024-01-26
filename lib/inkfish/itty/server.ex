defmodule Inkfish.Itty.Server do
  use GenServer

  alias Inkfish.Itty.Tickets

  # How long to stay alive waiting for late
  # subscribers after the process terminates.
  @linger_seconds 120
  
  def start_link(state0) do
    IO.puts(" =[Itty]= Start server with UUID #{state0.uuid}")
    GenServer.start_link(__MODULE__, state0, name: reg(state0.uuid))
  end

  def reg(uuid) do
    {:via, Registry, {Inkfish.Itty.Reg, uuid}}
  end

  def start(uuid, qname, cmd, env, on_exit) do
    cookie = Inkfish.Text.gen_uuid()
    env = env
    |> Map.update("COOKIE", cookie, &(&1))
    state0 = %{
      qname: qname,
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
  def init(%{qname: qname} = state0) do
    ticket = Tickets.ticket(qname)
    data = %{
      seq: 0,
      blocks: [],
      done: false,
      started: false,
      ticket: ticket
    }
    {:ok, Map.merge(state0, data)}
  end

  def start_cmd(%{cmd: cmd, env: env} = _state0) do
    env = System.get_env()
    |> Map.merge(env)
    |> Enum.into([])

    IO.puts(" =[Itty]= Run cmd for UUID #{state0.uuid}")
    #IO.inspect({:run, cmd, Enum.with_index(env)}, limit: :infinity)

    opts = [{:stdout, self()}, {:stderr, self()}, {:env, env},
	    {:kill_timeout, 5}, :monitor]
    {:ok, _pid, _ospid} = :exec.run(cmd, opts, 30)
    :ok
  end

  def view(state) do
    outputs = [:adm, :out, :err]
    |> Enum.map(fn stream ->
      {stream, get_stream_text(state, stream)}
    end)
    |> Enum.into(%{})

    view = state
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

  def send_block(block, %{uuid: uuid, seq: seq, blocks: blocks} = state) do
    blocks = [block | blocks]
    IO.puts(" =[Itty]= Send block for UUID #{state0.uuid} #{block.seq}")
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "ittys:" <> uuid, {:block, uuid, block})
    {:noreply, %{state | seq: seq + 1, blocks: blocks}}
  end

  @impl true
  def handle_info({:now_serving, serving, _}, state) do
    %{seq: seq, ticket: ticket} = state
    text = "Now serving #{serving}. We are #{ticket}.\n"
    block = %{seq: seq, stream: :adm, text: text}
    if ticket <= serving do
      start_cmd(state)
    end
    send_block(block, state)
  end

  def handle_info({:stdout, _, text}, %{seq: seq} = state) do
    block = %{seq: seq, stream: :out, text: text}
    send_block(block, state)
  end

  def handle_info({:stderr, _, text}, %{seq: seq} = state) do
    block = %{seq: seq, stream: :err, text: text} 
    send_block(block, state)
  end

  def handle_info({:DOWN, _, _, _, status}, state) do
    %{uuid: uuid, on_exit: on_exit, qname: qname,
      ticket: ticket, blocks: blocks} = state

    IO.puts(" =[Itty]= Send done for UUID #{state0.uuid}")
    Phoenix.PubSub.broadcast!(Inkfish.PubSub, "ittys:" <> uuid, {:done, uuid})
    Tickets.done(qname, ticket)

    if on_exit do
      rv = %{
	    uuid: uuid,
	    downstat: status,
	    status: "ok",
	    result: get_marked_output(state, state.cookie),
	    log: blocks,
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
    IO.inspect {:info, foo}
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
    splits = get_stream_text(state, :out)
    |> String.split("\n#{cookie}\n", trim: true)

    if length(splits) > 1 do
      Enum.at(splits, 1)
    else
      ""
    end
  end
end
