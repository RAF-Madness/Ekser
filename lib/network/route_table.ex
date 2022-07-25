defmodule Ekser.RouteTable do
  require Ekser.FractalId
  require Ekser.Node

  @enforce_keys [:bootstrap, :curr]
  defstruct [
    :bootstrap,
    :curr,
    :prev,
    :next,
    cluster_neighbours: [],
    last_id: 0
  ]

  @spec get_next(%__MODULE__{}, %Ekser.Node{}, integer()) ::
          {:ok, %Ekser.Node{}} | {:error, String.t()}
  def get_next(table, receiver, sender_id) do
    last_id =
      case sender_id > table.last_id do
        true -> 0
        false -> table.last_id
      end

    best_node =
      extract_neighbours(table)
      |> Stream.map(fn node -> {node, get_min_distance(node, receiver, last_id)} end)
      |> Enum.reduce_while(:error, fn element, acc -> least_hoops(element, acc) end)

    case best_node do
      :error -> {:error, "No adequate neighbours!"}
      {node, _} -> {:ok, node}
    end
  end

  defp extract_neighbours(table) do
    cond do
      table.next != nil and table.prev != nil ->
        [table.next, table.prev | table.cluster_neighbours]

      table.next != nil and table.prev === nil ->
        [table.next | table.cluster_neighbours]

      table.next === nil and table.prev != nil ->
        [table.prev | table.cluster_neighbours]

      table.next === nil and table.prev === nil ->
        table.cluster_neighbours
    end
  end

  defp least_hoops({node, dist}, acc) do
    cond do
      dist === 0 -> {:halt, {node, dist}}
      is_integer(dist) and not is_tuple(acc) -> {:cont, {node, dist}}
      is_integer(dist) and elem(acc, 1) > dist -> {:cont, {node, dist}}
      true -> {:cont, acc}
    end
  end

  defp get_min_distance(node, element, last_id) do
    chain_distance =
      case last_id > 0 do
        true ->
          min(
            abs(node.id - element.id),
            last_id + 1 - max(node.id, element.id) + min(node.id, element.id)
          )

        false ->
          abs(node.id - element.id)
      end

    with true <- node.job_name != "",
         true <- node.job_name === element.job_name,
         cluster_dist when is_integer(cluster_dist) <-
           Ekser.FractalId.compare_edit_distance(
             node.fractal_id,
             element.fractal_id,
             chain_distance
           ) do
      cluster_dist
    else
      _ -> chain_distance
    end
  end
end
