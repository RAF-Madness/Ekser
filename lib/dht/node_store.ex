defmodule Ekser.NodeStore do
  require Ekser.TCP
  require Ekser.Node
  require Ekser.DHT
  use Agent

  # Client API

  def start_link(opts) do
    {curr, just_opts} = Keyword.pop!(opts, :value)
    Agent.start_link(Ekser.NodeMap, :init, [curr], just_opts)
  end

  @spec introduce_new() :: %{
          id: pos_integer(),
          nodes: %{pos_integer() => %Ekser.Node{}}
        }
  def introduce_new() do
    nodes = Agent.get(Ekser.NodeStore, Ekser.NodeMap, :get_nodes, [])
    {curr, popped_nodes} = Map.pop!(nodes, :curr)
    %{id: curr.id + 1, nodes: popped_nodes}
  end

  @spec enter_network(%Ekser.Node{}) :: :ok
  def enter_network(node) do
    Agent.update(__MODULE__, Ekser.NodeMap, :add_node, [node])
  end

  @spec leave_network(%Ekser.Node{}) :: :ok
  def leave_network(node) do
    Agent.update(__MODULE__, Ekser.NodeMap, :remove_node, [node])
  end

  @spec receive_node(%Ekser.Node{}) :: :ok | :unchanged
  def receive_node(node) do
    Agent.get_and_update(__MODULE__, Ekser.NodeMap, :update_node, [node])
  end

  @spec receive_system(%Ekser.DHT{}) ::
          {%Ekser.Node{}, %Ekser.Node{}} | {%Ekser.Node{}, nil}
  def receive_system(dht) do
    Agent.get_and_update(__MODULE__, Ekser.NodeMap, :set_system, [dht.id, dht.nodes])
  end

  @spec get_nodes(list(String.t())) :: %{pos_integer() => %Ekser.Node{}}
  def get_nodes(arg_list) do
    Agent.get(__MODULE__, Ekser.NodeMap, :get_nodes, arg_list)
  end

  @spec get_cluster_neighbours(String.t(), String.t()) :: %{pos_integer() => %Ekser.Node{}}
  def get_cluster_neighbours(job_name, fractal_id) do
    Agent.get_and_update(__MODULE__, Ekser.NodeMap, :get_cluster_neighbours, [
      job_name,
      fractal_id
    ])
  end

  def update_cluster(job_name, fractal_id) do
    Agent.update(__MODULE__, Ekser.NodeMap, :update_curr_fractal, [job_name, fractal_id])
  end

  @spec get_next_fractal_id() :: String.t() | :error
  def get_next_fractal_id() do
    Agent.get(__MODULE__, Ekser.NodeMap, :get_next_fractal_id, [])
  end
end
