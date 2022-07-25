defmodule Ekser.ChildServer do
  require Ekser.NodeStore
  require Ekser.Status
  use GenServer, restart: :transient

  # Client API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  # Server Functions

  @impl GenServer
  def init(args = [job, _]) do
    Registry.register(Ekser.AggregateReg, {Ekser.Message.Entered_Cluster, job.name}, nil)
    {:ok, args, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, [job, fractal_id]) do
    Ekser.Aggregate.register_non_vital()

    next_id =
      case fractal_id do
        "0" -> "0"
        _ -> fractal_id <> "0"
      end

    {:noreply, {[], job.count, fractal_id, next_id, false}}
  end

  @impl GenServer
  def handle_call(
        {:response, payload},
        _from,
        {responses, count, fractal_id, next_id, ready}
      ) do
    new_responses =
      case Ekser.FractalId.is_child?(fractal_id, payload.fractal_id) do
        true ->
          Ekser.Router.add_cluster_neighbour(payload)
          [payload | responses]

        false ->
          responses
      end

    case length(new_responses) === count - 1 and ready do
      true ->
        Ekser.FractalServer.redistribute(new_responses, next_id)
        {:reply, :ok, {[], count, next_id, next_id <> "0", true}}

      false ->
        {:reply, :ok, {new_responses, count, fractal_id, next_id, ready}}
    end
  end

  @impl GenServer
  def handle_call(:stop, _from, _) do
    exit(:shutdown)
  end

  @impl GenServer
  def handle_cast(:clear, {responses, count, fractal_id, next_id, _}) do
    case length(responses) === count - 1 do
      true ->
        Ekser.FractalServer.redistribute(responses, next_id)
        {:noreply, {[], count, next_id, next_id <> "0", true}}

      false ->
        {:noreply, {responses, count, fractal_id, next_id, true}}
    end
  end
end
