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
    {curr, popped_nodes} = Map.pop(nodes, :curr)

    {proper_nodes, start_info} =
      case curr do
        nil ->
          {popped_nodes, nil}

        node ->
          {Map.pop!(popped_nodes, node.id), Ekser.FractalServ.get_progress()}
      end

    :ok =
      proper_nodes
      |> Map.values()
      |> Ekser.Message.StatusRequest.new(name)
      |> Ekser.Router.send()

    waiting_responses = Map.new(proper_nodes, fn {k, _} -> {k, nil} end)

    responses =
      case start_info do
        nil ->
          waiting_responses

        calculated ->
          Map.put(
            waiting_responses,
            curr.id,
            Ekser.Status.new(name, curr.job_name, curr.fractal_id, calculated)
          )
      end
      |> Map.merge(map)

    {:noreply, {name, output, responses}}
  end

  @impl GenServer
  def handle_continue(:init, [name, output, job_name, fractal_id]) do
    map = %{job: job_name, fractal_id: fractal_id}

    Ekser.NodeStore.get_nodes([job_name, fractal_id])
    |> prepare(name, output, map)
  end

  @impl GenServer
  def handle_continue(:init, [name, output, job_name]) do
    map = %{job: job_name}

    Ekser.NodeStore.get_nodes([job_name])
    |> prepare(name, output, map)
  end

  @impl GenServer
  def handle_continue(:init, [name, output]) do
    Ekser.NodeStore.get_nodes([])
    |> prepare(name, output, %{})
  end

  @impl GenServer
  def handle_cast({:response, id, response}, {name, output, responses}) do
    status =
      Ekser.Status.new(
        name,
        Map.get_lazy(responses, :job_name, fn -> response.job_name end),
        Map.get_lazy(responses, :fractal_id, fn -> response.fractal_id end),
        response.points
      )

    new_responses = Map.put(responses, id, status)

    case is_complete?(new_responses) do
      true ->
        {_, removed_job_map} = Map.pop(new_responses, :job_name)
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
      |> Enum.chunk_by(fn element -> element.job_name end)
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

    [Enum.at(section_results, 0).job_name, ":\n" | section_results]
  end
end
