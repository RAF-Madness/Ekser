defmodule Ekser.ResultServ do
  require Ekser.NodeStore
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

  defp prepare(nodes, name, output, job) do
    {curr, popped_nodes} = Map.pop(nodes, :curr)

    {proper_nodes, start_info} =
      case curr do
        nil ->
          {popped_nodes, nil}

        node ->
          {Map.pop!(popped_nodes, node.id), Ekser.FractalServ.get_work()}
      end

    :ok =
      proper_nodes
      |> Ekser.Message.ResultRequest.new(name)
      |> Ekser.Router.send()

    waiting_responses = Map.new(proper_nodes, fn {k, _} -> {k, nil} end)

    {responses, points} =
      case start_info do
        nil ->
          {waiting_responses, []}

        _ ->
          {waiting_responses, start_info}
      end

    {:noreply, {name, output, job.resolution, responses, points}}
  end

  @impl GenServer
  def handle_continue(:id, [name, output, job]) do
    Ekser.NodeStore.get_nodes([job.name])
    |> prepare(name, output, job)
  end

  @impl GenServer
  def handle_continue(:job, [name, output, job, fractal_id]) do
    Ekser.NodeStore.get_nodes([job.name, fractal_id])
    |> prepare(name, output, job)
  end

  @impl GenServer
  def handle_cast({:response, id, response}, {name, output, resolution, responses, list}) do
    new_responses = Map.put(responses, id, response)
    new_list = list ++ response.points

    case is_complete?(new_responses) do
      true -> complete(name, output, resolution, new_list)
      false -> {:noreply, {name, output, resolution, new_responses, new_list}}
    end
  end

  defp is_complete?(responses) do
    Enum.all?(responses.values, fn element -> element !== nil end)
  end

  defp complete(name, output, resolution, results) do
    IO.inspect(output, results)

    file =
      name
      |> Path.expand()
      |> File.open!([:write])

    png =
      :png.create(%{
        size: resolution,
        mode: {:rgba, 8},
        file: file
      })

    # Append points
    stream =
      Enum.sort_by(results, fn {_, y} -> y end)
      |> Stream.chunk_by(fn {_, y} -> y end)

    height_drawn =
      Enum.reduce(stream, fn list, acc ->
        new_acc = check_rows(list, acc, png, elem(resolution, 1))
        generate_pixels(png, elem(resolution, 1), Enum.map(list, fn {x, _} -> x end))
        new_acc + 1
      end)

    fill_rows(elem(resolution, 0) - height_drawn, height_drawn, png, elem(resolution, 1))

    :png.close(png)
    File.close(file)
    IO.puts(output, [name, ".png is now available."])
    exit(:shutdown)
  end

  defp check_rows(list, acc, png, width) do
    [{_, y}] = Enum.take(list, 1)

    fill_rows(y - acc, acc, png, width)
  end

  defp fill_rows(height_dist, acc, png, width) do
    case height_dist do
      0 ->
        acc

      _ ->
        generate_pixels(png, width, [])
        fill_rows(height_dist - 1, acc + 1, png, width)
    end
  end

  defp generate_pixels(png, width, pixel_list) do
    row =
      Stream.iterate(0, &(&1 + 1))
      |> Stream.take(width)
      |> Enum.map(fn index ->
        case index in pixel_list do
          true -> <<255, 0, 0, 255>>
          false -> <<0, 0, 0, 0>>
        end
      end)

    :png.append(png, {:row, row})
  end
end
