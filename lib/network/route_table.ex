defmodule Ekser.RouteTable do
  require Ekser.FractalId
  require Ekser.Node

  @enforce_keys [:bootstrap, :curr]
  defstruct [
    :bootstrap,
    :curr,
    :prev,
    :next,
    cluster_neighbours: []
  ]

  @spec get_next(%__MODULE__{}, %Ekser.Node{}) ::
          {:ok, %Ekser.Node{}} | {:error, String.t()}
  def get_next(table, receiver) do
    best_node =
      extract_neighbours(table)
      |> Stream.map(fn node -> {node, get_min_distance(node, receiver)} end)
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

  defp get_min_distance(node, element) do
    chain_distance = abs(node.id - element.id)

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
