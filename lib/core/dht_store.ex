defmodule Ekser.DHTStore do
  require Ekser.TCP
  require Ekser.Node
  use Agent

  # Client API

  def start_link(opts) do
    {curr, just_opts} = Keyword.pop!(opts, :value)
    Agent.start_link(__MODULE__, :init, [curr], just_opts)
  end

  def introduce_new(agent, node) when Ekser.Node.is_node(node) do
    nodes = Agent.get(agent, __MODULE__, :get_nodes, [])
    %{id: nodes.curr.id + 1, nodes: nodes}
  end

  def enter_network(agent, node) when Ekser.Node.is_node(node) do
    Agent.update(agent, __MODULE__, :add_node, [node])
  end

  def change_cluster(agent, node) when Ekser.Node.is_node(node) do
    Agent.update(agent, __MODULE__, :update_node, [node])
  end

  def leave_network(agent, node) when Ekser.Node.is_node(node) do
    Agent.update(agent, __MODULE__, :remove_node, [node])
  end

  def receive_system(agent, id, nodes) when is_integer(id) and is_map(nodes) do
    case Ekser.Serializable.valid_map?(nodes, Ekser.Node) do
      true -> Agent.update(agent, __MODULE__, :set_system, [id, nodes])
      false -> {:error, "Not a valid node map."}
    end
  end

  def get_nodes_by_criteria(agent, job_name, fractal_id)
      when is_binary(job_name) and is_binary(fractal_id) do
    Agent.get(agent, __MODULE__, :get_nodes, [job_name, fractal_id])
  end

  def get_nodes_by_criteria(agent, job_name) when is_binary(job_name) do
    Agent.get(agent, __MODULE__, :get_nodes, [job_name])
  end

  # Server Functions

  def init(curr) do
    %{curr: curr}
  end

  def get_nodes(nodes, job_name, fractal_id) do
    Enum.filter(Map.values(nodes), fn element ->
      element.job_name === job_name and element.fractal_id === fractal_id
    end)
  end

  def get_nodes(nodes, job_name) do
    Enum.filter(Map.values(nodes), fn element ->
      element.job_name === job_name
    end)
  end

  def get_nodes(nodes) do
    nodes
  end

  def add_node(nodes, node) do
    Map.put(nodes, node.id, node)
  end

  def update_node(nodes, node) do
    case Ekser.Node.equal?(nodes.curr, node) do
      true -> %{nodes | :curr => node, node.id => node}
      false -> %{nodes | node.id => node}
    end
  end

  def remove_node(nodes, id) do
    Map.delete(nodes, id)
  end

  def set_system(nodes, id, system_nodes) do
    curr = %Ekser.Node{nodes.curr | id: id}

    Map.merge(nodes, system_nodes)
    |> Map.put(curr.id, curr)
    |> Map.put(:curr, curr)
  end
end
