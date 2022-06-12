defmodule Ekser.Router do
  require Ekser.TCP
  require Ekser.Node
  require Ekser.RouteTable
  require Ekser.Message
  use GenServer

  # Client API

  @spec update_curr(atom(), %Ekser.Node{}) :: :ok
  def update_curr(server, node) when Ekser.Node.is_node(node) do
    GenServer.call(server, {:curr, node})
  end

  @spec receive_contact(atom(), %Ekser.Node{}) :: :ok
  def receive_contact(server, node) when Ekser.Node.is_node(node) do
    set_prev(server, node)
  end

  @spec introduce_new(atom(), %Ekser.Node{}) :: :ok
  def introduce_new(server, node) do
    GenServer.call(server, {:introduce, node})
  end

  @spec add_cluster_neighbour(atom(), %Ekser.Node{}) :: :ok
  def add_cluster_neighbour(server, node) when Ekser.Node.is_node(node) do
    GenServer.call(server, {:cluster_neighbours, node})
  end

  @spec set_prev(atom(), %Ekser.Node{}) :: :ok
  def set_prev(server, node) when Ekser.Node.is_node(node) do
    GenServer.call(server, {:prev, node})
  end

  @spec set_next(atom(), %Ekser.Node{}) :: :ok
  def set_next(server, node) when Ekser.Node.is_node(node) do
    GenServer.call(server, {:next, node})
  end

  @spec forward(atom(), %Ekser.Message{}) :: :ok
  def forward(server, message) when Ekser.Message.is_message(message) do
    GenServer.cast(server, {:forward, message})
  end

  @spec send(atom(), function()) :: :ok
  def send(server, closure) when is_function(closure) do
    GenServer.cast(server, {:send, closure})
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
  def handle_call({:introduce, node}, _from, table) do
    new_node = Ekser.Node.new(table.curr.id + 1, node.ip, node.port, "", "")
    {:reply, :ok, %Ekser.RouteTable{table | next: new_node}}
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
        appended_message <- Ekser.Message.append_route(message, table.curr.id),
        {:ok, route_to} <- Ekser.RouteTable.get_next(table, appended_message.receiver) do
      send(appended_message, route_to.ip, route_to.port)
    end

    {:noreply, table}
  end

  defp send(json, ip, port) do
    Task.Supervisor.start_child(Ekser.SenderSup, fn -> Ekser.TCP.send(json, ip, port) end)
  end
end
