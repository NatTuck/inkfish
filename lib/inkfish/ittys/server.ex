defmodule Inkfish.Ittys.Server do
  use GenServer

  alias Inkfish.Ittys.Task
  alias Inkfish.Ittys.Job
  alias Inkfish.Sandbox.AgImage
  alias Inkfish.Sandbox.Containers
  alias Inkfish.Ittys.Block

  # How long to stay alive waiting for late
  # subscribers after the job terminates.
  @linger_seconds 300

  # If the output ever gets longer than this
  # in characters we need to give up.
  @max_output_size 1_000_000

  def start_link(%Job{} = job) do
    IO.puts(" =[Itty]= Start server with UUID #{job.uuid}")
    GenServer.start_link(__MODULE__, job, name: reg(job.uuid))
  end

  def reg(uuid) do
    {:via, Registry, {Inkfish.Ittys.Reg, uuid}}
  end

  def start(%Job{} = job) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [job]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(Inkfish.Ittys.DynSup, spec)
  end

  def peek(uuid) do
    if !Enum.empty?(Registry.lookup(Inkfish.Ittys.Reg, uuid)) do
      GenServer.call(reg(uuid), :peek)
    else
      {:error, :itty_not_found}
    end
  end

  def running?(uuid) do
    if Enum.empty?(Registry.lookup(Inkfish.Ittys.Reg, uuid)) do
      false
    else
      {:ok, state} = GenServer.call(reg(uuid), :peek)
      !state.done
    end
  end

  def stop(uuid) do
    if !Enum.empty?(Registry.lookup(Inkfish.Ittys.Reg, uuid)) do
      GenServer.call(reg(uuid), :stop)
    else
      :ok
    end
  end

  @impl true
  def init(%Job{} = job) do
    IO.puts("Itty: UUID #{job.uuid}")
    Process.send_after(self(), :start_next, 1)
    {:ok, job}
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
      |> Map.drop([:__struct__, :on_exit])
      |> Map.put(:done, Enum.empty?(state.tasks))
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

  def handle_call(:stop, _from, %Job{ospid: ospid} = state) do
    send_text("Stopping process early.\n", state)

    if ospid do
      :exec.stop(ospid)
    end

    Process.send_after(self(), :shutdown, 5000)
    {:reply, :ok, state}
  end

  def send_text(text, state) do
    send_text(:adm, text, state)
  end

  def send_text(stream, text, %{seq: seq} = state) do
    block = Block.new(seq, stream, text)
    send_block(block, state)
  end

  def send_block(
        %Block{} = block,
        %{uuid: uuid, seq: seq, blocks: blocks} = state
      ) do
    blocks1 = [block | blocks]

    output_size = Enum.sum_by(blocks1, & &1.length)

    {block, blocks} =
      if output_size < @max_output_size do
        {block, blocks1}
      else
        if state.ospid do
          :exec.stop(state.ospid)
        end

        Process.send_after(self(), :shutdown, 5000)

        eblock = Block.new(seq, :adm, "\nHit output limit, bye.\n")
        {eblock, [eblock | blocks]}
      end

    Phoenix.PubSub.broadcast!(
      Inkfish.PubSub,
      "ittys:" <> uuid,
      {:block, uuid, block}
    )

    {:noreply, %{state | seq: seq + 1, blocks: blocks}}
  end

  def start_cmd(%Task{} = task, cmd, state) do
    env =
      System.get_env()
      |> Map.merge(task.env)
      |> Map.put("COOKIE", state.cookie)
      |> Enum.into([])

    IO.puts(" =[Itty]= Run cmd [#{cmd}] for UUID #{state.uuid}")

    opts = [
      {:stdout, self()},
      {:stderr, self()},
      {:env, env},
      {:kill_timeout, 15 * 60},
      :monitor
    ]

    {:ok, _pid, ospid} = :exec.run(cmd, opts, 30)

    send_text(
      "\nStarting task: #{task.label}\n\n",
      Map.put(state, :ospid, ospid)
    )
  end

  def start_build_image(task, conf, state) do
    conf = Map.put(conf, "COOKIE", state.cookie)

    case AgImage.prepare(conf) do
      {:ok, %AgImage{tag: tag, cmd: cmd}} ->
        IO.inspect({:created_ag_image, tag})
        start_cmd(task, cmd, state)

      error ->
        send_text("\nError in build_image: #{inspect(error)}\n\n", state)
    end
  end

  def start_run_container(task, %{cmd: cmd, img: img} = _conf, state) do
    cont_id = Containers.create(image: img)
    start_cmd(Task.put_env(task, "CID", cont_id), cmd, state)
  end

  @impl true
  def handle_info(:start_next, %{tasks: [task | _rest]} = state) do
    case task.action do
      {:cmd, cmd} ->
        start_cmd(task, cmd, state)

      {:build_image, conf} ->
        start_build_image(task, conf, state)

      {:run_container, job} ->
        start_run_container(task, job, state)

      _else ->
        IO.puts("Itty: unknown action #{inspect(task.action)}")
        {:noreply, state}
    end
  end

  def handle_info({:stdout, _, text}, %{seq: seq} = state) do
    block = Block.new(seq, :out, text)
    send_block(block, state)
  end

  def handle_info({:stderr, _, text}, %{seq: seq} = state) do
    block = Block.new(seq, :err, text)
    send_block(block, state)
  end

  def handle_info({:send, text}, %{seq: seq} = state) do
    block = Block.new(seq, :adm, text)
    send_block(block, state)
  end

  def handle_info({:DOWN, _, _, _, status}, state) do
    %{uuid: uuid, blocks: blocks, tasks: tasks} = state

    IO.puts(" =[Itty]= Child done for UUID #{uuid}")

    if length(tasks) == 0 do
      IO.puts("Itty: Unexpected empty task list.")
    else
      task = hd(tasks)

      if task.on_exit do
        rv = %{
          uuid: uuid,
          downstat: status,
          status: "ok",
          result: get_marked_output(state, state.cookie),
          log: blocks
        }

        case task.on_exit.(rv) do
          {:send, text} ->
            IO.inspect({:send, text})
            Process.send_after(self(), {:send, text}, 1)

          _else ->
            IO.inspect({:on_exit, :empty})
            :pass
        end
      end
    end

    rest = Enum.drop(tasks, 1)

    if length(rest) == 0 do
      Process.send_after(self(), :send_done, 100)
      Process.send_after(self(), :shutdown, @linger_seconds * 1000)
    else
      Process.send_after(self(), :start_next, 10)
    end

    {:noreply, %{state | tasks: rest}}
  end

  def handle_info(:send_done, %{uuid: uuid} = state0) do
    Phoenix.PubSub.broadcast!(
      Inkfish.PubSub,
      "ittys:" <> uuid,
      {:done, uuid}
    )

    {:noreply, state0}
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
      |> String.replace("\r", "")
      |> String.split("\n#{cookie}\n", trim: true)

    if length(splits) > 1 do
      Enum.at(splits, 1)
    else
      ""
    end
  end
end
