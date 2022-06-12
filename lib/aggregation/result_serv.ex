defmodule Ekser.ResultServ do
  require Ekser.DHTStore
  use GenServer, restart: :transient

  # Client API

  def start_link([identifier | args]) do
    name = string_name(identifier)
    registry_name = via_tuple(name)
    GenServer.start_link(__MODULE__, [name | args], name: registry_name)
  end

  def respond(identifier, id, payload) when is_integer(id) and is_list(payload) do
    GenServer.cast(via_tuple(identifier), {:response, {id, payload}})
  end

  # Server Functions

  defp string_name(identifier) do
    "result#{identifier}"
  end

  defp via_tuple(string_name) do
    {:via, Registry, {AggregatorRegistry, string_name}}
  end

  defp generate_handle(name) do
    Path.expand(name)
    |> File.open!([:write])
  end

  defp generate_png(handle, resolution) do
    :png.create(%{
      size: resolution,
      mode: {:indexed, 8},
      file: handle,
      palette: {:rgb, 8, [{255, 0, 0}]}
    })
  end

  defp new_state(name, resolution, printer, map) do
    handle = generate_handle(name)

    case map do
      nil -> {{name, handle, generate_png(handle, resolution), printer}}
      _ -> {{name, handle, generate_png(handle, resolution), printer}, map}
    end
  end

  @impl GenServer
  def init([name, printer, job]) do
    {:ok, {name, printer, job}, {:continue, :job}}
  end

  @impl GenServer
  def init([name, printer, job, fractal_id]) do
    {:ok, {name, printer, job, fractal_id}, {:continue, :id}}
  end

  @impl GenServer
  def handle_continue(:id, {name, printer, job}) do
    Ekser.DHTStore.get_nodes_by_criteria(Ekser.DHTStore, job.name)
    # Send messages
    {:noreply, new_state(name, job.resolution, printer, nil)}
  end

  @impl GenServer
  def handle_continue(:job, {name, printer, job, fractal_id}) do
    Ekser.DHTStore.get_nodes_by_criteria(Ekser.DHTStore, job.name, fractal_id)
    # Send messages
    {:noreply, new_state(name, job.resolution, printer, %{})}
  end

  @impl GenServer
  def handle_cast({:response, {id, response}}, {output, responses})
      when is_map(responses) do
    # :png.append
    new_responses = Map.put(responses, id, response)

    case is_complete?(new_responses) do
      true -> complete(output, new_responses.values)
      false -> {:noreply, {output, new_responses}}
    end
  end

  @impl GenServer
  def handle_cast({:response, {_, response}}, output) do
    # :png.append
    complete(output, response)
  end

  defp is_complete?(responses) do
    Enum.all?(responses.values, fn element -> element !== nil end)
  end

  defp complete({name, handle, png, printer}, results) do
    IO.inspect(printer, results)
    :png.close(png)
    File.close(handle)
    IO.puts(printer, [name, " is now available."])
    exit(:shutdown)
  end
end
