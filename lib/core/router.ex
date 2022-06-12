defmodule Ekser.Router do
  require Ekser.TCP
  require Ekser.Node
  require Ekser.RouteTable
  require Ekser.Message
  use GenServer

  # Client API

  def update_curr(server, node) when Ekser.Node.is_node(node) do
    GenServer.call(server, {:curr, node})
  end

  def receive_contact(server, node) when Ekser.Node.is_node(node) do
    set_prev(server, node)
  end

  def add_cluster_neighbour(server, node) when Ekser.Node.is_node(node) do
    GenServer.call(server, {:cluster_neighbours, node})
  end

  def set_prev(server, node) when Ekser.Node.is_node(node) do
    GenServer.call(server, {:prev, node})
  end

  def set_next(server, node) when Ekser.Node.is_node(node) do
    GenServer.call(server, {:next, node})
  end

  def introduce_new(server, id, table) do
    GenServer.call(server, {:assign_next, id, table})
  end

  def forward(server, message) when Ekser.Message.is_message(message) do
    GenServer.cast(server, {:forward, message})
  end

  def send(server, node) when Ekser.Node.is_node(node) do
    GenServer.cast(server, {:send, node})
  end

  def hail(server) do
    GenServer.call(server, :hail)
  end

  # Server Functions

  @impl GenServer
  def init({bootstrap, curr}) do
    {:ok, %Ekser.RouteTable{bootstrap: bootstrap, curr: curr}}
  end

  @impl GenServer
  def handle_call({:curr, node}, _from, table) do
    {:reply, :ok, %Ekser.RouteTable{table | curr: node}}
  end

  @impl GenServer
  def handle_call({:cluster_neighbours, node}, _from, table) do
    {:reply, :ok,
     %Ekser.RouteTable{table | cluster_neighbours: [node | table.cluster_neighbours]}}
  end

  @impl GenServer
  def handle_call({:prev, node}, _from, table) do
    {:reply, :ok, %Ekser.RouteTable{table | prev: node}}
  end

  @impl GenServer
  def handle_call({:next, node}, _from, table) do
    {:reply, :ok, %Ekser.RouteTable{table | next: node}}
  end

  @impl GenServer
  def handle_call({:bootstrap, closure}, _from, table) do
    closure.(table.curr, table.bootstrap)
    {:reply, :ok, table}
  end

  @impl GenServer
  def handle_cast({:forward, message}, table) do
    {:ok, route_to} = Ekser.RouteTable.get_next(table, message.receiver)

    Ekser.Message.append_route(message, table.curr.id)
    |> Jason.encode!()
    |> send(route_to.ip, route_to.port)

    {:noreply, table}
  end

  @impl GenServer
  def handle_cast({:send, closure}, table) do
    message_list = closure.(table.curr)

    for message <- message_list,
        {:ok, route_to} <- Ekser.RouteTable.get_next(table, message.receiver) do
      send(message, route_to.ip, route_to.port)
    end

    {:noreply, table}
  end

  defp send(json, ip, port) do
    Task.Supervisor.start_child(Ekser.SenderSup, fn -> Ekser.TCP.send(json, ip, port) end)
  end
end
