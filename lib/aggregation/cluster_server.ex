defmodule Ekser.ClusterServer do
  require Ekser.NodeStore
  use GenServer, restart: :transient

  # Client API

  def start_link([args]) do
    GenServer.start_link(__MODULE__, args)
  end

  # Server Functions

  @impl GenServer
  def init(args) do
    {:ok, args, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, [job_name, fractal_id]) do
    {responses, _} =
      Ekser.NodeStore.get_cluster_neighbours(job_name, fractal_id)
      |> Ekser.Aggregate.init(
        Ekser.Message.ClusterConnectionRequest,
        Ekser.Message.ClusterConnectoinResponse,
        fn -> nil end,
        nil
      )

    Ekser.Aggregate.continue_or_exit(responses)

    try_complete(responses)
  end

  @impl GenServer
  def handle_call({:response, id, payload}, _from, responses) do
    new_responses = %{responses | id => true}
    try_complete(new_responses)
  end

  @impl GenServer
  def handle_call(:stop, _from, state) do
    exit(:shutdown)
  end

  defp try_complete(responses) do
    case Ekser.Aggregate.is_complete?(responses) do
      true -> complete()
      false -> {:noreply, responses}
    end
  end

  defp complete() do
    nodes =
      Ekser.NodeStore.get_nodes([])
      |> Map.values()

    fn curr -> Enum.map(nodes, fn node -> Ekser.Message.EnteredCluster.new(curr, node) end) end
    |> Ekser.Router.send()

    exit(:shutdown)
  end
end
