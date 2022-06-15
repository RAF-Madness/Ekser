defmodule Ekser.Message.Entered do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  def new(curr, receiver) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.NodeStore.enter_network(message.sender)
  end
end

defmodule Ekser.Message.ConnectionResponse do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  def new(curr, receiver) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    :ok = Ekser.Router.set_next(message.sender)

    {curr, nodes} =
      Ekser.NodeStore.get_nodes([])
      |> Map.pop!(:curr)

    receivers =
      nodes
      |> Map.pop(curr.id)
      |> elem(1)
      |> Map.values()

    closure = fn curr ->
      receivers |> Enum.map(fn receiver -> Ekser.Message.Entered.new(curr, receiver) end)
    end

    {:send, closure}
  end
end

defmodule Ekser.Message.ConnectionRequest do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  def new(curr, receiver) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    :ok = Ekser.Router.set_prev(message.sender)
    {:send, fn curr -> [Ekser.Message.ConnectionResponse.new(curr, message.sender)] end}
  end
end

defmodule Ekser.Message.Welcome do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_struct(payload, Ekser.DHT) do
      true -> payload
      false -> Ekser.DHT.create_from_json(payload)
    end
  end

  def new(curr, receiver, dht) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], dht)
  end

  @impl Ekser.Message
  def send_effect(message) do
    :ok = Ekser.Router.set_prev(message.sender)
    :ok = Ekser.JobStore.receive_system(message.payload)
    number = Ekser.NodeMap.get_number_of_jobs(message.payload.nodes)

    first_node = Ekser.NodeStore.receive_system(message.payload)

    case number do
      0 ->
        {:send, fn curr -> [Ekser.Message.ConnectionRequest.new(curr, first_node)] end}

      _ ->
        cluster_node = message.payload.nodes[number]

        {:send,
         fn curr ->
           [
             Ekser.Message.ConnectionRequest.new(curr, first_node),
             Ekser.Message.ClusterKnock.new(curr, cluster_node)
           ]
         end}
    end
  end
end

defmodule Ekser.Message.SystemKnock do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  def new(curr, receiver) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    :ok = Ekser.Router.introduce_new(message.sender)
    map = Ekser.NodeStore.introduce_new()
    jobs = Ekser.JobStore.get_all_jobs()
    dht = Ekser.DHT.new(map.id, map.nodes, jobs)
    {:send, fn curr -> [Ekser.Message.Welcome.new(curr, message.sender, dht)] end}
  end
end

defmodule Ekser.Message.Quit do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  def new(curr, receiver) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.NodeStore.leave_network(message.sender)
  end
end
