defmodule Ekser.ResultServer do
  require Ekser.NodeStore
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
  def handle_continue(:init, [output, job | rest]) do
    arg_list = [job.name] ++ rest

    {responses, local_info} =
      Ekser.NodeStore.get_nodes(arg_list)
      |> Ekser.Aggregate.init(
        Ekser.Message.Result_Request,
        Ekser.Message.Result_Response,
        fn -> Ekser.FractalServer.result() end,
        nil
      )

    Ekser.Aggregate.continue_or_exit(responses)

    Ekser.Aggregate.register_non_vital()

    initial_results =
      case local_info === nil do
        true -> []
        false -> local_info.points
      end

    case Ekser.Aggregate.is_complete?(responses) do
      true -> {:noreply, {initial_results, output, job.resolution}, {:continue, :complete}}
      false -> {:noreply, {responses, initial_results, output, job.resolution}}
    end
  end

  @impl GenServer
  def handle_continue(:complete, {results, output, resolution}) do
    file =
      "result.png"
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
      Enum.reduce(stream, 0, fn list, acc ->
        new_acc = check_rows(list, acc, png, elem(resolution, 1))
        generate_pixels(png, elem(resolution, 1), Enum.map(list, fn {x, _} -> x end))
        new_acc + 1
      end)

    fill_rows(elem(resolution, 0) - height_drawn, height_drawn, png, elem(resolution, 1))

    :png.close(png)
    File.close(file)
    IO.puts(output, "result.png is now available.")
    exit(:shutdown)
  end

  @impl GenServer
  def handle_call({:response, id, payload}, _from, {responses, results, output, resolution}) do
    new_results = results ++ payload.points
    new_responses = %{responses | id => true}
    try_complete(new_responses, new_results, output, resolution)
  end

  @impl GenServer
  def handle_call(:stop, _from, _) do
    exit(:shutdown)
  end

  defp try_complete(responses, results, output, resolution) do
    case Ekser.Aggregate.is_complete?(responses) do
      true -> {:reply, :ok, {results, output, resolution}, {:continue, :complete}}
      false -> {:reply, :ok, {responses, results, output, resolution}}
    end
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
