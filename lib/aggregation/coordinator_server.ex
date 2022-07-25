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
    Ekser.JobStore.receive_job(job)

    {responses, local_info} =
      Ekser.NodeStore.get_nodes([])
      |> Ekser.Aggregate.init(
        Ekser.Message.Stop_Share_Job,
        Ekser.Message.Stopped_Job_Info,
        fn -> Ekser.FractalServer.stop() end,
        job
      )

    Ekser.Aggregate.continue_or_exit(responses)

    initial_results =
      case local_info === nil do
        true -> %{}
        false -> Ekser.Result.get_friendly(local_info)
      end

    {:noreply, {responses, Map.put(initial_results, job.name, []), output}}
  end

  @impl GenServer
  def handle_continue(:init, [:stop, output, _]) do
    {responses, _} =
      Ekser.NodeStore.get_nodes([])
      |> Ekser.Aggregate.init(
        Ekser.Message.Stop_Share_Job,
        Ekser.Message.Stopped_Job_Info,
        fn -> Ekser.FractalServer.stop() end,
        nil
      )

    Ekser.Aggregate.continue_or_exit(responses)

    {:noreply, {responses, %{}, output}}
  end

  @impl GenServer
  def handle_continue(:complete, {results, output}) do
    individual_results =
      results
      |> Map.pop("")
      |> elem(1)
      |> Map.to_list()
      |> Enum.map(fn {job_name, points} -> Ekser.Result.new(job_name, points) end)

    all_nodes = Ekser.NodeStore.get_nodes([])

    {curr, nodes_without_curr} = Map.pop(all_nodes, :curr)

    nodes =
      nodes_without_curr
      |> Map.values()
      |> Enum.sort_by(fn node -> node.id end)

    {genesis_nodes, leftover_nodes} = Enum.split(nodes, length(individual_results))

    genesis_node_stream = Stream.cycle(genesis_nodes)

    Ekser.Aggregate.close_non_vital()

    # 2 cases - curr in zipped genesis, curr in zipped leftover

    zipped_genesis = Enum.zip(genesis_nodes, individual_results) |> remove_from_genesis(curr)

    {zipped_leftover, message} =
      Enum.zip(leftover_nodes, genesis_node_stream) |> remove_from_leftover(curr)

    # For DHT
    updated_zipped_genesis =
      Enum.map(zipped_genesis, fn {node, result} ->
        new_node = %Ekser.Node{node | job_name: result.job_name, fractal_id: "0"}
        Ekser.NodeStore.receive_node(new_node)
        {new_node, result}
      end)

    fn curr ->
      Enum.map(updated_zipped_genesis, fn {receiver, result} ->
        Ekser.Message.Start_Job_Genesis.new(curr, receiver, result)
      end) ++
        Enum.map(zipped_leftover, fn {receiver, payload} ->
          Ekser.Message.Approach_Cluster.new(curr, receiver, payload)
        end)
    end
    |> Ekser.Router.send()

    :ok =
      case message != nil do
        true ->
          message
          |> Ekser.Router.send()

        false ->
          :ok
      end

    IO.puts(output, "Reorganized clusters.")
    exit(:shutdown)
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
      true -> {:reply, :ok, {results, output}, {:continue, :complete}}
      false -> {:reply, :ok, {responses, results, output}}
    end
  end

  defp remove_from_genesis(zipped_genesis, curr) do
    case Enum.find(zipped_genesis, fn {node, _} -> node.id === curr.id end) do
      nil ->
        :ok

      {_, result} ->
        job = Ekser.JobStore.get_job_by_name(result.job_name)
        Ekser.FractalServer.join_cluster(job, "0")
        Ekser.FractalServer.start_job(result.points)
    end

    Enum.reject(zipped_genesis, fn {node, _} -> node.id === curr.id end)
  end

  defp remove_from_leftover(zipped_leftover, curr) do
    message =
      case Enum.find(zipped_leftover, fn {node, _} -> node.id === curr.id end) do
        nil ->
          nil

        {_, genesis} ->
          fn curr -> [Ekser.Message.Cluster_Knock.new(curr, genesis)] end
      end

    {Enum.reject(zipped_leftover, fn {node, _} -> node.id === curr.id end), message}
  end
end
