defmodule Ekser.NodeMap do
  # Agent Functions

  def init(curr) do
    %{curr: curr}
  end

  def update_curr_fractal(nodes, job_name, fractal_id) do
    new_curr = %Ekser.Node{nodes.curr | job_name: job_name, fractal_id: fractal_id}
    Ekser.Router.update_curr(new_curr)
    %{Map.put(nodes, new_curr.id, new_curr) | curr: new_curr}
  end

  def get_cluster_neighbours(nodes, job_name, fractal_id) do
    new_nodes = update_curr_fractal(nodes, job_name, fractal_id)

    neighbours =
      new_nodes
      |> Map.filter(fn {_, node} ->
        Ekser.FractalId.compare_edit_distance(new_nodes.curr.fractal_id, node.fractal_id, 1) === 1
      end)

    {neighbours, new_nodes}
  end

  defp get_number_of_jobs(nodes) do
    nodes
    |> Map.values()
    |> Enum.map(fn node -> node.job_name end)
    |> Enum.filter(fn name -> name != "" end)
    |> Enum.uniq()
    |> length()
  end

  def get_next_fractal_id(nodes) do
    job = Ekser.JobStore.get_job_by_name(nodes.curr.job_name)

    case job do
      nil ->
        :error

      _ ->
        job_nodes =
          nodes
          |> Map.values()
          |> Stream.filter(fn node -> node.job_name === nodes.curr.job_name end)

        max =
          Enum.max_by(job_nodes, fn node -> String.length(node.fractal_id) end).fractal_id
          |> String.length()

        [top_id] =
          Stream.filter(job_nodes, fn node -> String.length(node.fractal_id) === max end)
          |> Stream.map(fn node -> node.fractal_id end)
          |> Enum.sort_by(fn fractal_id -> String.to_integer(fractal_id, job.count) end)
          |> Enum.reverse()
          |> Enum.take(1)

        Ekser.FractalId.get_next(top_id, job.count)
    end
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

      Ekser.Node.same_node?(nodes[:curr], node) ->
        Ekser.Router.update_curr(node)
        {:ok, %{Map.put(nodes, node.id, node) | curr: node}}

      true ->
        {:ok, %{nodes | node.id => node}}
    end
  end

  def remove_node(nodes, id) do
    Map.delete(nodes, id)
  end

  def set_system(nodes, id, system_nodes) do
    curr = %Ekser.Node{nodes.curr | id: id}
    Ekser.Router.update_curr(curr)

    new_nodes =
      Map.merge(nodes, system_nodes)
      |> Map.put(curr.id, curr)
      |> Map.put(:curr, curr)

    cluster_node =
      case get_number_of_jobs(nodes) do
        0 -> nil
        number -> new_nodes[id - number]
      end

    {{new_nodes[0], cluster_node}, new_nodes}
  end
end
