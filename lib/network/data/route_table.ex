defmodule Ekser.RouteTable do
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
  def get_next(table, node) do
    best_node =
      extract_neighbours(table)
      |> Stream.map(fn element -> {element, get_min_distance(node, element)} end)
      |> Enum.reduce_while(:error, fn element, acc -> least_hoops(element, acc) end)

    case best_node do
      :error -> {:error, "No adequate neighbours!"}
      {node, _} -> {:ok, node}
    end
  end

  @spec calculate_fractal_neighbours(%Ekser.Node{}, list(%Ekser.Node{})) :: list(%Ekser.Node{})
  def calculate_fractal_neighbours(node, nodes) do
    Enum.filter(nodes, fn element ->
      compare_edit_distance(node.fractal_id, element.fractal_id, 1) === 1
    end)
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
           compare_edit_distance(node.fractal_id, element.fractal_id, chain_distance) do
      cluster_dist
    else
      _ -> chain_distance
    end
  end

  defp compare_edit_distance(fractal_id, other, value) do
    length = max(String.length(fractal_id), String.length(other))

    padded_id =
      String.pad_trailing(fractal_id, length, ["0"])
      |> String.graphemes()

    padded_other =
      String.pad_trailing(other, length, ["0"])
      |> String.graphemes()

    Stream.zip(padded_id, padded_other)
    |> Enum.reduce_while(0, fn element, acc -> calculate_edit_distance(element, acc, value) end)
  end

  defp calculate_edit_distance({char1, char2}, acc, value) do
    cond do
      char1 === char2 and acc === value ->
        {:halt, false}

      char1 === char2 ->
        {:cont, acc + 1}

      true ->
        {:cont, acc}
    end
  end
end
