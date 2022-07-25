defmodule Ekser.Aggregate do
  def new(child_spec) do
    Ekser.WorkSup.start_child(child_spec)
  end

  def continue_or_exit(nodes) do
    case nodes === %{} do
      true -> exit(:shutdown)
      false -> nodes
    end
  end

  def init(nodes, message_module, response_module, self_function, arg) do
    {curr, nodes_without_curr} = Map.pop(nodes, :curr)

    nodes_to_send =
      case curr do
        nil ->
          nodes

        node ->
          {_, new_map} = Map.pop(nodes_without_curr, node.id)
          new_map
      end

    case nodes_to_send === %{} do
      false ->
        nodes_to_send
        |> Map.keys()
        |> register_keys(response_module)

        receivers =
          nodes_to_send
          |> Map.values()

        fn curr ->
          Enum.map(receivers, fn receiver -> message_module.new(curr, receiver, arg) end)
        end
        |> Ekser.Router.send()

      true ->
        :ok
    end

    responses = Map.new(nodes_without_curr, fn {k, _} -> {k, false} end)

    case curr do
      nil -> {responses, nil}
      _ -> {Map.put(responses, curr.id, true), self_function.()}
    end
  end

  defp register_keys(node_ids, message_module) do
    Enum.each(node_ids, fn id ->
      Registry.register(Ekser.AggregateReg, {message_module, id}, nil)
    end)

    :ok
  end

  def register_non_vital() do
    Registry.register(Ekser.AggregateReg, :non_vital, nil)
  end

  def close_non_vital() do
    Registry.dispatch(Ekser.AggregateReg, :non_vital, fn entries ->
      for {pid, _} <- entries,
          do: GenServer.call(pid, :stop)
    end)
  end

  def is_complete?(responses) do
    Enum.all?(Map.values(responses), fn value -> value === true end)
  end

  def respond(message) do
    Registry.dispatch(Ekser.AggregateReg, {message.type, message.sender.id}, fn entries ->
      for {pid, _} <- entries,
          do: GenServer.call(pid, {:response, message.sender.id, message.payload})
    end)
  end

  def respond_job(message) do
    Registry.dispatch(Ekser.AggregateReg, {message.type, message.payload.job_name}, fn entries ->
      for {pid, _} <- entries,
          do: GenServer.call(pid, {:response, message.payload})
    end)
  end
end
