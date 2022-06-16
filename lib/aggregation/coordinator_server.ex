defmodule Ekser.CoordinatorServer do
  require Ekser.NodeStore
  use GenServer, restart: :transient

  # StoppedJobInfo aggregator

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
  def handle_continue(:init, [:start, output, job]) do
    arg =
      case Ekser.JobStore.receive_job(job) do
        :unchanged -> nil
        :ok -> job
      end

    {responses, local_info} =
      Ekser.NodeStore.get_nodes([])
      |> Ekser.Aggregate.init(
        Ekser.Message.StopShareJob,
        Ekser.Message.StoppedJobInfo,
        fn -> Ekser.FractalServer.stop() end,
        arg
      )

    Ekser.Aggregate.continue_or_exit(responses)

    initial_results =
      case local_info === nil do
        true -> %{}
        false -> Ekser.Result.get_friendly(local_info)
      end

    try_complete(responses, initial_results, output)
  end

  @impl GenServer
  def handle_continue(:init, [:stop, output, _]) do
    {responses, _} =
      Ekser.NodeStore.get_nodes([])
      |> Ekser.Aggregate.init(
        Ekser.Message.StopShareJob,
        Ekser.Message.StoppedJobInfo,
        fn -> Ekser.FractalServer.stop() end,
        nil
      )

    Ekser.Aggregate.continue_or_exit(responses)

    try_complete(responses, %{}, output)
  end

  @impl GenServer
  def handle_call({:response, id, payload}, _from, {responses, results, output}) do
    new_results = Ekser.Result.merge_result(results, payload)
    new_responses = %{responses | id => true}
    try_complete(new_responses, new_results, output)
  end

  @impl GenServer
  def handle_call({:response, id, payload}, _from, {responses, results, output, job_name}) do
    new_results =
      case payload.job_name === job_name do
        true -> results
        false -> Ekser.Result.merge_result(results, payload)
      end

    new_responses = %{responses | id => true}
    try_complete(new_responses, new_results, output)
  end

  defp try_complete(responses, results, output) do
    case Ekser.Aggregate.is_complete?(responses) do
      true -> complete(results, output)
      false -> {:noreply, {responses, results, output}}
    end
  end

  defp complete(results, output) do
    job_names = Map.keys(results)

    nodes =
      Ekser.NodeStore.get_nodes([])
      |> Map.values()
      |> Enum.sort_by(fn node -> node.id end)

    {genesis_nodes, leftover_nodes} = Enum.split(nodes, length(job_names))

    genesis_node_stream = Stream.cycle(genesis_nodes)

    zipped_genesis = Enum.zip(genesis_nodes, job_names)
    zipped_leftover = Enum.zip(leftover_nodes, genesis_node_stream)

    # For DHT
    updated_zipped_genesis =
      Enum.map(zipped_genesis, fn {node, job_name} ->
        new_node = %Ekser.Node{node | job_name: job_name, fractal_id: "0"}
        Ekser.NodeStore.receive_node(new_node)
        {new_node, job_name}
      end)

    fn curr ->
      Enum.map(updated_zipped_genesis, fn {node, job_name} ->
        Ekser.Message.StartJobGenesis.new(curr, node, job_name)
      end) ++
        Enum.map(zipped_leftover, fn {receiver, payload} ->
          Ekser.Message.ApproachCluster.new(curr, receiver, payload)
        end)
    end
    |> Ekser.Router.send()

    IO.puts(output, "Reorganized clusters.")
  end
end
