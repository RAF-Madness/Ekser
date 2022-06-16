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
    {:ok, %__MODULE__{}}
  end

  @impl GenServer
  def handle_call({:join, job, fractal_id}, _from, state) when state.job === nil do
    Ekser.NodeStore.update_cluster(job.name, fractal_id)

    new_state = %__MODULE__{state | job: job, fractal_id: fractal_id, anchors: job.points}

    scaled_state =
      case new_state.job != nil and new_state.points != nil do
        true -> set_up(new_state)
        false -> new_state
      end

    {:reply, :ok, scaled_state}
  end

  @impl GenServer
  def handle_call({:join, _, _}, _from, state) do
    {:reply, :error, state}
  end

  @impl GenServer
  def handle_call({:start, points}, _from, state) when state.points === nil do
    new_state = %__MODULE__{state | points: points}

    scaled_state =
      case new_state.job != nil and new_state.points != nil do
        true -> set_up(new_state)
        false -> new_state
      end

    {:reply, :ok, scaled_state}
  end

  @impl GenServer
  def handle_call({:start, _}, _from, state) do
    {:reply, :error, state}
  end

  @impl GenServer
  def handle_call({:redistribute, nodes, new_id}, _from, state) do
    # This call has to update DHT/Router with Curr and send an UpdatedNode message because of it
    # But this isn't supposed to happen if the new_id is the same as the one in state

    :ok =
      case new_id === state.fractal_id do
        true ->
          :ok

        false ->
          Ekser.NodeStore.update_cluster(state.job_name, new_id)

          fn curr ->
            Enum.map(nodes, fn node -> Ekser.Message.Start_Job.new(curr, node, state.points) end)
          end
          |> Ekser.Router.send()
      end

    new_state = %__MODULE__{state | fractal_id: new_id}
    {:reply, :ok, new_state}
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

    case state.cruncher do
      nil -> true
      _ -> Process.exit(state.cruncher, :shutdown)
    end

    result = Ekser.Result.new(state.job.name, new_points)

    {:reply, result, %__MODULE__{}}
  end

  @impl GenServer
  def handle_call(:stop, _from, _) do
    result = Ekser.Result.new("", [])

    {:reply, result, %__MODULE__{}}
  end

  @impl GenServer
  def handle_call(:status, _from, state) when state.job != nil and state.points != nil do
    status = Ekser.Status.new(state.job.name, state.fractal_id, state.count)
    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) when state.job != nil do
    status = Ekser.Status.new(state.job.name, state.fractal_id, 0)
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
    case old_cruncher === state.cruncher do
      true ->
        Process.demonitor(old_cruncher)
        cruncher = start_cruncher(state)
        new_state = %__MODULE__{state | cruncher: cruncher}
        {:noreply, new_state}

      false ->
        {:noreply, state}
    end
  end

  defp set_up(state) do
    {scaled_anchors, scaled_points} =
      case state.fractal_id === "0" do
        true ->
          {state.anchors, state.points}

        false ->
          Ekser.Point.scale_to_fractal_id(
            state.job.ratio,
            state.fractal_id,
            {state.anchors, Enum.reverse(state.points)}
          )
      end

    new_state = %__MODULE__{
      state
      | anchors: scaled_anchors,
        points: scaled_points,
        count: length(scaled_anchors) + length(scaled_points)
    }

    %__MODULE__{new_state | cruncher: start_cruncher(new_state)}
  end

  defp clean_list(state) do
    %__MODULE__{state | points: Enum.uniq(state.points)}
  end

  defp get_proper_list(state) do
    state.anchors ++ Enum.reverse(state.points)
  end

  defp start_cruncher(state) do
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
end
