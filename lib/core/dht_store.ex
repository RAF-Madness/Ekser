defmodule Ekser.DHTStore do
  require Ekser.TCP
  require Ekser.Node
  require Ekser.DHT
  use Agent

  # Client API

  def start_link(opts) do
    {curr, just_opts} = Keyword.pop!(opts, :value)
    Agent.start_link(__MODULE__, :init, [curr], just_opts)
  end

  @spec introduce_new(atom()) :: %{
          id: pos_integer(),
          nodes: %{pos_integer() => %Ekser.Node{}}
        }
  def introduce_new(agent) do
    nodes = Agent.get(agent, __MODULE__, :get_nodes, [])
    {_, popped_nodes} = Map.pop!(nodes, :curr)
    %{id: nodes.curr.id + 1, nodes: popped_nodes}
  end

  @spec enter_network(atom(), %Ekser.Node{}) :: :ok
  def enter_network(agent, node) when Ekser.Node.is_node(node) do
    Agent.update(agent, __MODULE__, :add_node, [node])
  end

  @spec change_cluster(atom(), %Ekser.Node{}) :: :ok
  def change_cluster(agent, node) when Ekser.Node.is_node(node) do
    Agent.update(agent, __MODULE__, :update_node, [node])
  end

  @spec leave_network(atom(), %Ekser.Node{}) :: :ok
  def leave_network(agent, node) when Ekser.Node.is_node(node) do
    Agent.update(agent, __MODULE__, :remove_node, [node])
  end

  @spec receive_system(atom(), %Ekser.DHT{}) ::
          %Ekser.Node{} | {:error, String.t()}
  def receive_system(agent, dht) do
    Agent.get_and_update(agent, __MODULE__, :set_system, [dht.id, dht.nodes])
  end

  @spec get_nodes_by_criteria(atom(), String.t(), String.t()) :: list(%Ekser.Node{})
  def get_nodes_by_criteria(agent, job_name, fractal_id)
      when is_binary(job_name) and is_binary(fractal_id) do
    Agent.get(agent, __MODULE__, :get_nodes, [job_name, fractal_id])
  end

  @spec get_nodes_by_criteria(atom(), String.t()) :: list(%Ekser.Node{})
  def get_nodes_by_criteria(agent, job_name) when is_binary(job_name) do
    Agent.get(agent, __MODULE__, :get_nodes, [job_name])
  end

  @spec get_all_nodes(atom()) :: %{pos_integer() => %Ekser.Node{}}
  def get_all_nodes(agent) do
    Agent.get(agent, __MODULE__, :get_nodes, [])
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

    new_nodes =
      Map.merge(nodes, system_nodes)
      |> Map.put(curr.id, curr)
      |> Map.put(:curr, curr)

    {new_nodes[0], new_nodes}
  end
end
