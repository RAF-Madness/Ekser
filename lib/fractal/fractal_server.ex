defmodule Ekser.FractalServer do
  require Ekser.Job
  use GenServer

  @enforce_keys [:job, :fractal_id, :cruncher, :anchors, :points, :count]
  defstruct @enforce_keys

  # This server is launched after StartJob is received.
  # Before this point, the node is either IDLE or is still in the initial phases.

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @spec receive_point(point()) :: :ok
  def receive_point(point) do
    GenServer.call(__MODULE__, {:point, point})
  end

  @spec join_cluster(%Ekser.Job{}, String.t()) :: :ok | :error
  def join_cluster(job, fractal_id) do
    GenServer.call(__MODULE__, {:join, job, fractal_id})
  end

  @spec start_job(list(point())) :: :ok | :error
  def start_job(points) do
    GenServer.call(__MODULE__, {:start, points})
  end

  def reorganise(nodes) do
    GenServer.call(__MODULE__, {:redistribute, nodes})
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
  def handle_call({:join, job, fractal_id}, state) when state.job === nil do
    new_state = %__MODULE__{state | job: job, fractal_id: fractal_id, anchors: job.points}

    scaled_state =
      case new_state.job != nil and new_state.points != nil do
        true -> set_up(new_state)
        false -> state
      end

    {:reply, :ok, scaled_state}
  end

  @impl GenServer
  def handle_call({:join, job, fractal_id}, state) do
    {:reply, :error, state}
  end

  @impl GenServer
  def handle_call({:start, points}, state) when state.points === nil do
    new_state = %__MODULE__{state | points: points}

    scaled_state =
      case new_state.job != nil and new_state.points != nil do
        true -> set_up(new_state)
        false -> state
      end

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:start, points}, state) do
    {:reply, :error, state}
  end

  @impl GenServer
  def handle_call({:redistribute, nodes}, state) do
    closure = fn curr ->
      Enum.map(nodes, fn node -> Ekser.Message.StartJob.new(curr, node, state.points) end)
    end

    Ekser.Router.send(closure)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:point, point}, _from, state) do
    new_state = %__MODULE__{state | points: [point | state.points], count: state.count + 1}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:stop, _from, state) do
    new_state = clean_list(state)
    result = Ekser.Result.new(new_state.job_name, get_proper_list(new_state))
    Process.exit(state.cruncher, :shutdown)
    {:reply, result, %__MODULE__{}}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    status = Ekser.Status.new(state.job.name, state.fractal_id, state.count)
    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:result, _from, state) do
    new_state = clean_list(state)
    result = Ekser.Result.new(new_state.job_name, get_proper_list(new_state))
    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_info({:DOWN, old_cruncher, _, _, _}, state) do
    case old_cruncher === state.cruncher do
      true ->
        Process.demonitor(old_cruncher)
        cruncher = start_cruncher(state.supervisor, old_cruncher)
        new_state = %__MODULE__{state | cruncher: cruncher}
        {:noreply, new_state}

      false ->
        {:noreply, state}
    end
  end

  defp set_up(state) do
    {scaled_anchors, scaled_points} =
      Ekser.Point.scale_to_fractal_id(
        state.job.ratio,
        state.fractal_id,
        {state.anchors, Enum.reverse(state.points)}
      )

    %__MODULE__{
      state
      | cruncher: start_cruncher(supervisor),
        anchors: scaled_anchors,
        points: scaled_points,
        count: length(scaled_anchors) + length(scaled_points)
    }
  end

  defp clean_list(state) do
    %__MODULE__{state | points: Enum.uniq(state.points)}
  end

  defp get_proper_list(state) do
    state.anchors ++ Enum.reverse(state.points)
  end

  defp start_cruncher(state) do
    [last_point | rest] = state.points

    {:ok, cruncher} =
      Ekser.WorkSup.start_child(
        Ekser.FractalCruncher.child_spec([state.job.ratio, state.anchors, last_point])
      )

    Process.monitor(cruncher)
  end
end
