defmodule Ekser.FractalServer do
  require Ekser.Job
  use GenServer

  defstruct [:job, :fractal_id, :cruncher, :anchors, :points, :count]

  # This server is launched after StartJob is received.
  # Before this point, the node is either IDLE or is still in the initial phases.

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @spec receive_point(Ekser.Point.point()) :: :ok
  def receive_point(point) do
    GenServer.call(__MODULE__, {:point, point})
  end

  @spec join_cluster(%Ekser.Job{}, String.t()) :: :ok | :error
  def join_cluster(job, fractal_id) do
    GenServer.call(__MODULE__, {:join, job, fractal_id})
  end

  @spec start_job(list(Ekser.Point.point())) :: :ok | :error
  def start_job(points) do
    GenServer.call(__MODULE__, {:start, points})
  end

  def redistribute(nodes, new_id) do
    GenServer.call(__MODULE__, {:redistribute, nodes, new_id})
  end

  def stop() do
    GenServer.call(__MODULE__, :stop)
  end

  def status() do
    GenServer.call(__MODULE__, :status)
  end

  def result() do
    GenServer.call(__MODULE__, :result)
  end

  # Server Functions

  @impl GenServer
  def init(:ok) do
    {:ok, %__MODULE__{count: 0}}
  end

  @impl GenServer
  def handle_call({:join, job, fractal_id}, _from, state) when state.job === nil do
    Ekser.NodeStore.update_cluster(job.name, fractal_id)

    new_state = %__MODULE__{state | job: job, fractal_id: fractal_id, anchors: job.points}

    Ekser.ChildServer.child_spec([job, fractal_id])
    |> Ekser.Aggregate.new()

    scaled_state =
      cond do
        new_state.fractal_id != "0" and new_state.points != nil ->
          scale_state(new_state) |> set_up_cruncher()

        new_state.points != nil ->
          set_up_cruncher(new_state)

        true ->
          new_state
      end

    all_nodes = Ekser.NodeStore.get_nodes([])
    {curr, nodes_without_curr} = Map.pop(all_nodes, :curr)

    receivers =
      Map.pop(nodes_without_curr, curr.id)
      |> elem(1)
      |> Map.values()

    fn curr ->
      Enum.map(receivers, fn receiver ->
        Ekser.Message.Entered_Cluster.new(curr, receiver, curr)
      end)
    end
    |> Ekser.Router.send()

    {:reply, :ok, scaled_state}
  end

  @impl GenServer
  def handle_call({:join, _, _}, _from, state) do
    {:reply, :error, state}
  end

  @impl GenServer
  def handle_call({:start, points}, _from, state) when state.points === nil do
    new_state = %__MODULE__{state | points: Enum.reverse(points)}

    scaled_state =
      cond do
        new_state.fractal_id != "0" and new_state.job != nil ->
          scale_state(new_state) |> set_up_cruncher()

        new_state.job != nil ->
          set_up_cruncher(new_state)

        true ->
          new_state
      end

    {:reply, :ok, scaled_state}
  end

  @impl GenServer
  def handle_call({:start, _}, _from, state) do
    {:reply, :error, state}
  end

  @impl GenServer
  def handle_call({:redistribute, nodes, new_id}, _from, state) do
    scaled_state = %__MODULE__{state | fractal_id: new_id} |> scale_state() |> set_up_cruncher()
    result = Ekser.Result.new(state.job.name, state.points)

    fn curr ->
      Enum.map(nodes, fn node -> Ekser.Message.Start_Job.new(curr, node, result) end)
    end
    |> Ekser.Router.send()

    :ok =
      case new_id === state.fractal_id do
        true ->
          :ok

        false ->
          Ekser.NodeStore.update_cluster(state.job.name, new_id)
          all_nodes = Ekser.NodeStore.get_nodes([])
          {curr, nodes_without_curr} = Map.pop(all_nodes, :curr)

          receivers =
            Map.pop(nodes_without_curr, curr.id)
            |> elem(1)
            |> Map.values()

          fn curr ->
            Enum.map(receivers, fn receiver ->
              Ekser.Message.Updated_Node.new(curr, receiver, curr)
            end)
          end
          |> Ekser.Router.send()
      end

    {:reply, :ok, scaled_state}
  end

  @impl GenServer
  def handle_call({:point, point}, _from, state) when state.points != nil do
    new_state = %__MODULE__{state | points: [point | state.points], count: state.count + 1}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:point, _}, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:stop, _from, state) when state.job != nil and state.points != nil do
    new_points =
      clean_list(state)
      |> get_proper_list()

    stop_cruncher(state.cruncher)

    result = Ekser.Result.new(state.job.name, new_points)

    {:reply, result, %__MODULE__{}}
  end

  @impl GenServer
  def handle_call(:stop, _from, _) do
    result = Ekser.Result.new("", [])

    {:reply, result, %__MODULE__{count: 0}}
  end

  @impl GenServer
  def handle_call(:status, _from, state) when state.job != nil do
    status = Ekser.Status.new(state.job.name, state.fractal_id, state.count)
    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    status = Ekser.Status.new("", "", 0)
    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:result, _from, state) when state.job != nil and state.points != nil do
    new_state = clean_list(state)
    result = Ekser.Result.new(new_state.job.name, get_proper_list(new_state))
    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call(:result, _from, state) do
    result = Ekser.Result.new("", [])
    {:reply, result, state}
  end

  @impl GenServer
  def handle_info({:DOWN, old_cruncher, _, _, _}, state) do
    Process.demonitor(old_cruncher)

    case old_cruncher === state.cruncher do
      true ->
        cruncher = start_cruncher(state)
        new_state = %__MODULE__{state | cruncher: cruncher}
        {:noreply, new_state}

      false ->
        {:noreply, state}
    end
  end

  defp scale_state(state) do
    {scaled_anchors, scaled_points} =
      Ekser.Point.scale_to_fractal_id(
        state.job.ratio,
        state.fractal_id,
        {state.anchors, state.points}
      )

    set_state(state, scaled_anchors, scaled_points)
  end

  defp set_state(state, anchors, points) do
    %__MODULE__{state | anchors: anchors, points: points, count: length(anchors) + length(points)}
  end

  defp set_up_cruncher(state) do
    Registry.dispatch(
      Ekser.AggregateReg,
      {Ekser.Message.Entered_Cluster, state.job.name},
      fn entries ->
        for {pid, _} <- entries,
            do: GenServer.cast(pid, :clear)
      end
    )

    %__MODULE__{state | cruncher: start_cruncher(state)}
  end

  defp clean_list(state) do
    %__MODULE__{state | points: Enum.uniq(state.points)}
  end

  defp get_proper_list(state) do
    state.anchors ++ Enum.reverse(state.points)
  end

  defp start_cruncher(state) do
    stop_cruncher(state.cruncher)

    point =
      case length(state.points) do
        0 ->
          Enum.at(state.anchors, 0)

        _ ->
          [last_point | _] = state.points
          last_point
      end

    {:ok, cruncher} =
      Ekser.WorkSup.start_child(
        Ekser.FractalCruncher.child_spec([state.job.ratio, state.anchors, point])
      )

    Process.monitor(cruncher)
    cruncher
  end

  defp stop_cruncher(cruncher) do
    case cruncher do
      nil -> true
      _ -> Process.exit(cruncher, :shutdown)
    end
  end
end
