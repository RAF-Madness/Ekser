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
    {_, popped_nodes} = Map.pop!(nodes, :curr)
    %{id: nodes.curr.id + 1, nodes: popped_nodes}
  end

  @spec enter_network(%Ekser.Node{}) :: :ok
  def enter_network(node) do
    Agent.update(Ekser.NodeStore, Ekser.NodeMap, :add_node, [node])
  end

  @spec leave_network(%Ekser.Node{}) :: :ok
  def leave_network(node) do
    Agent.update(Ekser.NodeStore, Ekser.NodeMap, :remove_node, [node])
  end

  @spec receive_node(%Ekser.Node{}) :: :ok | :unchanged
  def receive_node(node) do
    Agent.get_and_update(Ekser.NodeStore, Ekser.NodeMap, :update_node, [node])
  end

  @spec receive_system(%Ekser.DHT{}) ::
          %Ekser.Node{} | {:error, String.t()}
  def receive_system(dht) do
    Agent.get_and_update(Ekser.NodeStore, Ekser.NodeMap, :set_system, [dht.id, dht.nodes])
  end

  @spec get_nodes(list(String.t())) :: %{pos_integer() => %Ekser.Node{}}
  def get_nodes(arg_list) do
    Agent.get(Ekser.NodeStore, Ekser.NodeMap, :get_nodes, arg_list)
  end
end
