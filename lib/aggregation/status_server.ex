defmodule Ekser.StatusServer do
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
  def handle_continue(:init, [output | rest]) do
    {responses, local_info} =
      Ekser.NodeStore.get_nodes(rest)
      |> Ekser.Aggregate.init(
        Ekser.Message.Status_Request,
        Ekser.Message.Status_Response,
        fn -> Ekser.FractalServer.status() end,
        nil
      )

    Ekser.Aggregate.continue_or_exit(responses)

    Ekser.Aggregate.register_non_vital()

    initial_results =
      case local_info === nil do
        true -> %{}
        false -> Ekser.Status.get_friendly(local_info)
      end

    case Ekser.Aggregate.is_complete?(responses) do
      true -> {:noreply, {initial_results, output}, {:continue, :complete}}
      false -> {:noreply, {responses, initial_results, output}}
    end
  end

  @impl GenServer
  def handle_continue(:complete, {results, output}) do
    to_print = Ekser.Status.get_status_string(results)

    IO.write(output, to_print)
    exit(:shutdown)
  end

  @impl GenServer
  def handle_call({:response, id, payload}, _from, {responses, results, output}) do
    new_results = Ekser.Status.merge_status(results, payload)
    new_responses = %{responses | id => true}
    try_complete(new_responses, new_results, output)
  end

  @impl GenServer
  def handle_call(:stop, _from, _) do
    exit(:shutdown)
  end

  defp try_complete(responses, results, output) do
    case Ekser.Aggregate.is_complete?(responses) do
      true -> {:reply, :ok, {results, output}, {:continue, :complete}}
      false -> {:reply, :ok, {responses, results, output}}
    end
  end
end
