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

    :ok =
      case nodes_to_send === %{} do
        false ->
          :ok

        true ->
          receivers =
            nodes_to_send
            |> Map.values()
            |> register_keys(response_module)

          fn curr ->
            Enum.map(receivers, fn receiver -> message_module.new(curr, receiver, arg) end)
          end
          |> Ekser.Router.send()
      end

    responses = Map.new(nodes_without_curr, fn {k, _} -> {k, false} end)

    case curr do
      nil -> {responses, nil}
      _ -> {responses, self_function.()}
    end
  end

  defp register_keys(node_ids, message_module) do
    Enum.each(node_ids, fn id ->
      Registry.register(Registry.AggregateRegistry, {message_module, id}, nil)
    end)

    node_ids
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
          do: GenServer.call(pid, {:response, message.sender.id, message.payload})
    end)
  end
end
