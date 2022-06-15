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
  def init(args) do
    {:ok, args, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, [job, fractal_id]) do
    Registry.register(Registry.AggregateRegistry, {Ekser.Message.EnteredCluster, job.name}, nil)
    {:noreply, {[], job.count, fractal_id}}
  end

  @impl GenServer
  def handle_call({:response, id, payload}, _from, {responses, count, fractal_id}) do
    new_responses =
      case Ekser.FractalId.is_child?(fractal_id, payload.fractal_id) do
        true -> [payload | responses]
        false -> responses
      end

    case length(new_responses) === count do
      true ->
        Ekser.FractalServer.reorganise(responses)
        {:noreply, {[], count, fractal_id}}

      false ->
        {:noreply, {responses, count, fractal_id}}
    end
  end

  @impl GenServer
  def handle_call(:stop, _from, state) do
    exit(:shutdown)
  end
end
