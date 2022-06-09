defmodule Ekser.DHT do
  require Ekser.Node
  use Agent

  @enforce_keys [:bootstrap]
  defstruct [
    :bootstrap,
    :prev,
    :curr,
    :next,
    nodes: %{}
  ]

  # Client API

  def start_link(opts) do
    {{port, bootstrap}, just_opts} = Keyword.pop!(opts, :value)
    Agent.start_link(__MODULE__, :new, [port, bootstrap], just_opts)
  end

  def receive_contact(agent, node) when Ekser.Node.is_node(node) do
    Agent.update(agent, __MODULE__, :set_prev, [node])
  end

  def introduce_new(agent, node) when Ekser.Node.is_node(node) do
    Agent.update(agent, __MODULE__, :assign_next, [node])
  end

  def receive_system(agent, id, nodes) when is_integer(id) and is_map(nodes) do
    case Enum.find(Map.values(nodes), fn element -> !Ekser.Node.is_node(element) end) do
      nil -> Agent.update(agent, __MODULE__, :set_system, [id, nodes])
      _ -> {:error, "Nodes must be in the form of a map that binds node ID to node info."}
    end
  end

  def link(agent, node, direction) when Ekser.Node.is_node(node) do
    case direction do
      :prev -> Agent.update(agent, __MODULE__, :set_prev, [node])
      :next -> Agent.update(agent, __MODULE__, :set_next, [node])
    end
  end

  def get_from_dht(agent, keys) do
    with {true, _} <- {is_list(keys), "Provided keys must be in the form of a list."},
         {true, _} <-
           {Enum.all?(keys, &is_atom/1),
            "Provided keys must be atoms since all DHT keys are atoms."},
         {true, _} <-
           {keys in %__MODULE__{}.keys(), "Provided keys were not valid DHT entries."} do
      Agent.get(agent, __MODULE__, return_info, [keys])
    else
      {false, message} -> {:error, message}
    end
  end

  def get_chain(agent) do
    Agent.get(agent, __MODULE__, return_chain, [])
  end

  # Server Functions

  defp new(port, bootstrap) when Ekser.Util.is_tcp_port(port) and Ekser.Node.is_node(bootstrap) do
    ip =
      System.cmd("nslookup", ["myip.opendns.com", "resolver1.opendns.com"])
      |> String.split()
      |> Enum.at(7)
      |> Ekser.Util.to_ip()

    %__MODULE__{curr: Ekser.Node.new(-2, ip, port), bootstrap: bootstrap}
  end

  defp set_prev(dht, node) do
    %__MODULE__{dht | prev: node, nodes: Map.put(dht.nodes, node.id, node)}
  end

  defp set_next(dht, node) do
    %__MODULE__{dht | next: node, nodes: Map.put(dht.nodes, node.id, node)}
  end

  defp assign_next(dht, node) do
    new_id = dht.curr.id + 1
    new_node = %Ekser.Node{node | id: new_id}

    set_next(dht, new_node)
  end

  defp set_system(dht, id, nodes) do
    curr = Ekser.Node.create(id, dht.curr.ip, dht.curr.port)

    %__MODULE__{dht | curr: curr, nodes: nodes}
  end

  defp return_info(dht, keys) do
    for key <- keys, do: dht[key]
  end
end
