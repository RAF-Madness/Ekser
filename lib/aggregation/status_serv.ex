defmodule Ekser.StatusServ do
  require Ekser.NodeStore
  require Ekser.Status
  use GenServer, restart: :transient

  # Client API

  def start_link([identifier | args]) do
    name = string_name(identifier)
    GenServer.start_link(__MODULE__, [name | args], name: via_tuple(name))
  end

  def respond(pid, id, payload) do
    GenServer.cast(pid, {:response, id, payload})
  end

  # Server Functions

  defp string_name(identifier) do
    "result#{identifier}"
  end

  defp via_tuple(name) do
    {:via, Registry, {AggregatorRegistry, name}}
  end

  @impl GenServer
  def init(args) do
    {:ok, args, {:continue, :init}}
  end

  defp prepare(nodes, name, output, map) do
    :ok =
      nodes
      |> Ekser.Message.StatusRequest.new(name)
      |> Ekser.Router.send()

    responses =
      Enum.into(nodes, %{}, fn node -> {node.id, nil} end)
      |> Map.merge(map)

    {:noreply, {name, output, responses}}
  end

  @impl GenServer
  def handle_continue(:init, [name, output, job_name, fractal_id]) do
    map = %{job: job_name, fractal_id: fractal_id}

    Ekser.NodeStore.get_nodes_by_criteria([job_name, fractal_id])
    |> prepare(name, output, map)
  end

  @impl GenServer
  def handle_continue(:init, [name, output, job_name]) do
    map = %{job: job_name}

    Ekser.NodeStore.get_nodes_by_criteria([job_name])
    |> prepare(name, output, map)
  end

  @impl GenServer
  def handle_continue(:init, [name, output]) do
    Ekser.NodeStore.get_all_nodes()
    |> Map.values()
    |> prepare(name, output, %{})
  end

  @impl GenServer
  def handle_cast({:response, id, response}, {name, output, responses}) do
    status =
      Ekser.Status.new(
        name,
        Map.get_lazy(responses, :job, fn -> response.job end),
        Map.get_lazy(responses, :fractal_id, fn -> response.fractal_id end),
        response.points
      )

    new_responses = Map.put(responses, id, status)

    case is_complete?(new_responses) do
      true ->
        {_, removed_job_map} = Map.pop(new_responses, :job)
        {_, removed_fractal_map} = Map.pop(removed_job_map, :fractal_id)
        complete(name, output, removed_fractal_map)

      false ->
        {:noreply, {name, output, new_responses}}
    end
  end

  defp is_complete?(responses) do
    Enum.all?(responses.values, fn element -> element !== nil end)
  end

  defp complete(name, output, statuses) do
    status_lines =
      Enum.sort(statuses.values, Ekser.Status)
      |> Enum.chunk_by(fn element -> element.job end)
      |> Enum.reduce([], fn element, acc -> [section_to_string(element) | acc] end)

    to_print = ["Status ", name, " returned:", "\n" | status_lines]

    IO.write(output, to_print)
    exit(:shutdown)
  end

  defp section_to_string(section) do
    section_results =
      Enum.reduce(section, [], fn element, acc ->
        [Ekser.Status.to_iodata(element) | acc]
      end)

    [Enum.at(section_results, 0).job, ":\n" | section_results]
  end
end
