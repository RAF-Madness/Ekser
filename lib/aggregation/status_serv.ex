defmodule Ekser.StatusServ do
  require Ekser.DHTStore
  require Ekser.Status
  use GenServer, restart: :transient

  # Client API

  def start_link([identifier | args]) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(identifier))
  end

  def respond(identifier, id, payload) when is_integer(id) and is_map(payload) do
    GenServer.cast(via_tuple(identifier), {:response, Map.put(payload, :id, id)})
  end

  # Server Functions

  defp via_tuple(identifier) do
    {:via, Registry, {AggregatorRegistry, "status#{identifier}"}}
  end

  @impl GenServer
  def init([output]) do
    {:ok, {output, %{}}, {:continue, :all}}
  end

  @impl GenServer
  def init([output, job]) do
    {:ok, {output, job.name, %{}}, {:continue, :job}}
  end

  @impl GenServer
  def init([output, job, fractal_id]) do
    {:ok, {output, job.name, fractal_id}, {:continue, :id}}
  end

  @impl GenServer
  def handle_continue(:id, state = {_, job, fractal_id}) do
    Ekser.DHTStore.get_nodes_by_criteria(Ekser.DHTStore, job, fractal_id)
    # Send messages
    {:noreply, state}
  end

  @impl GenServer
  def handle_continue(:job, state = {_, job}) do
    Ekser.DHTStore.get_nodes_by_criteria(Ekser.DHTStore, job)
    # Send messages
    {:noreply, state}
  end

  @impl GenServer
  def handle_continue(:all, state) do
    # Send messages
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:response, response}, {output, responses}) when is_map(responses) do
    {:ok, status} = Ekser.Status.new(response["job"], response["fractal_id"], response["points"])

    new_responses = Map.put(responses, response.id, status)

    case is_complete?(new_responses) do
      true -> complete(output, new_responses.values)
      false -> {:noreply, {output, new_responses}}
    end
  end

  @impl GenServer
  def handle_cast({:response, response}, {output, job, responses}) when is_map(responses) do
    {:ok, status} = Ekser.Status.new(job, response["fractal_id"], response["points"])

    new_responses = Map.put(responses, response.id, status)

    case is_complete?(new_responses) do
      true -> complete(output, new_responses.values)
      false -> {:noreply, {output, job, new_responses}}
    end
  end

  @impl GenServer
  def handle_cast({:response, response}, {output, job, fractal_id}) do
    {:ok, status} = Ekser.Status.new(job, fractal_id, response["points"])
    complete(output, [status])
  end

  defp is_complete?(responses) do
    Enum.all?(responses.values, fn element -> element !== nil end)
  end

  defp complete(output, statuses) do
    to_print =
      Enum.sort(statuses, Ekser.Status)
      |> Enum.chunk_by(fn element -> element.job end)
      |> Enum.reduce([], fn element, acc -> [section_to_string(element) | acc] end)

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
