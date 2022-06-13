defmodule Ekser.NodeMap do
  # Agent Functions

  def init(curr) do
    %{curr: curr}
  end

  def get_nodes(nodes, job_name, fractal_id) do
    Map.filter(nodes, fn {_, node} ->
      node.job_name === job_name and node.fractal_id === fractal_id
    end)
  end

  def get_nodes(nodes, job_name) do
    Map.filter(nodes, fn {_, node} ->
      node.job_name === job_name
    end)
  end

  def get_nodes(nodes) do
    nodes
  end

  def add_node(nodes, node) do
    Map.put(nodes, node.id, node)
  end

  def update_node(nodes, node) do
    cond do
      nodes[node.id] === node ->
        {:unchanged, nodes}

      Ekser.Node.same_node?(nodes.curr, node) ->
        {:ok, %{nodes | node.id => node, curr: node}}

      true ->
        {:ok, %{nodes | node.id => node}}
    end
  end

  def remove_node(nodes, id) do
    Map.delete(nodes, id)
  end

  def set_system(nodes, id, system_nodes) do
    curr = %Ekser.Node{nodes.curr | id: id}

    new_nodes =
      Map.merge(nodes, system_nodes)
      |> Map.put(curr.id, curr)
      |> Map.put(:curr, curr)

    {new_nodes[0], new_nodes}
  end
end
