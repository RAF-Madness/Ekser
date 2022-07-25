defmodule Ekser.Router do
  require Logger
  require Ekser.TCP
  require Ekser.Node
  require Ekser.RouteTable
  require Ekser.Message
  use GenServer

  # Client API

  def start_link(opts) do
    {value, just_opts} = Keyword.pop!(opts, :value)
    GenServer.start_link(__MODULE__, value, just_opts)
  end

  @spec update_curr(%Ekser.Node{}) :: :ok
  def update_curr(node) do
    GenServer.call(Ekser.Router, {:curr, node})
  end

  @spec update_last_id(integer()) :: :ok
  def update_last_id(id) do
    GenServer.call(Ekser.Router, {:last_id, id})
  end

  @spec introduce_new(%Ekser.Node{}) :: :ok
  def introduce_new(node) do
    GenServer.call(Ekser.Router, {:introduce, node})
  end

  @spec add_cluster_neighbour(%Ekser.Node{}) :: :ok
  def add_cluster_neighbour(node) do
    GenServer.call(Ekser.Router, {:cluster_neighbours, node})
  end

  @spec wipe_cluster_neighbours() :: :ok
  def wipe_cluster_neighbours() do
    GenServer.call(Ekser.Router, :cluster_neighbours)
  end

  @spec set_prev(%Ekser.Node{}) :: :ok
  def set_prev(node) do
    GenServer.call(Ekser.Router, {:prev, node})
  end

  @spec set_next(%Ekser.Node{}) :: :ok
  def set_next(node) do
    GenServer.call(Ekser.Router, {:next, node})
  end

  @spec forward(%Ekser.Message{}) :: :ok
  def forward(message) do
    GenServer.cast(Ekser.Router, {:forward, message})
  end

  @spec send(function()) :: :ok
  def send(closure) do
    GenServer.cast(Ekser.Router, {:send, closure})
  end

  @spec bootstrap(function()) :: :ok
  def bootstrap(closure) do
    GenServer.call(Ekser.Router, {:bootstrap, closure})
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
  def handle_call(:cluster_neighbours, _from, table) do
    {:reply, :ok, %Ekser.RouteTable{table | cluster_neighbours: []}}
  end

  @impl GenServer
  def handle_call({:prev, node}, _from, table) do
    {:reply, :ok, %Ekser.RouteTable{table | prev: node, last_id: node.id}}
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
  def handle_call({:last_id, id}, _from, table) do
    {:reply, :ok, %Ekser.RouteTable{table | last_id: id}}
  end

  @impl GenServer
  def handle_call({:bootstrap, closure}, _from, table) do
    message = closure.(table.curr, table.bootstrap)

    Logger.info(
      "Sending #{message.sender.id}|#{message.receiver.id}|#{message.type} to bootstrap"
    )

    dispatch(message, message.receiver, table.curr.id)

    {:reply, :ok, table}
  end

  @impl GenServer
  def handle_cast({:forward, message}, table) do
    {:ok, route_to} = Ekser.RouteTable.get_next(table, message.receiver, message.sender.id)

    Logger.info(
      "Forwarding #{message.sender.id}|#{message.receiver.id}|#{message.type} to #{route_to.id}"
    )

    dispatch(message, route_to, table.curr.id)

    {:noreply, table}
  end

  @impl GenServer
  def handle_cast({:send, closure}, table) do
    message_list = closure.(table.curr)

    for message <- message_list do
      {:ok, route_to} = Ekser.RouteTable.get_next(table, message.receiver, message.sender.id)

      Logger.info(
        "Sending #{message.sender.id}|#{message.receiver.id}|#{message.type} to #{route_to.id}"
      )

      dispatch(message, route_to, table.curr.id)
    end

    {:noreply, table}
  end

  defp dispatch(message, receiver, id) do
    Ekser.Message.append_route(message, id)
    |> Jason.encode!()
    |> send(receiver.ip, receiver.port)
  end

  defp send(json, ip, port) do
    Task.Supervisor.start_child(Ekser.SenderSup, fn -> Ekser.TCP.send(json, ip, port) end)
  end
end
