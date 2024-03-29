defmodule Ekser.Message.Entered do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_struct(payload, Ekser.Node) do
      true -> payload
      false -> Ekser.Node.create_from_json(payload)
    end
  end

  def new(curr, receiver, node) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], node)
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.NodeStore.enter_network(message.payload)
    Ekser.Router.update_last_id(message.payload.id)
  end
end

defmodule Ekser.Message.Connection_Response do
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
      Enum.map(receivers, fn receiver -> Ekser.Message.Entered.new(curr, receiver, curr) end)
    end

    bootstrap_closure = fn curr, bootstrap ->
      Ekser.Message.Join.new(curr, bootstrap, curr)
    end

    {{:send, closure}, {:bootstrap, bootstrap_closure}}
  end
end

defmodule Ekser.Message.Connection_Request do
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
    {:send, fn curr -> [Ekser.Message.Connection_Response.new(curr, message.sender)] end}
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

    {first_node, cluster_node} = Ekser.NodeStore.receive_system(message.payload)

    case cluster_node do
      nil ->
        {:send, fn curr -> [Ekser.Message.Connection_Request.new(curr, first_node)] end}

      _ ->
        {:send,
         fn curr ->
           [
             Ekser.Message.Connection_Request.new(curr, first_node),
             Ekser.Message.Cluster_Knock.new(curr, cluster_node)
           ]
         end}
    end
  end
end

defmodule Ekser.Message.System_Knock do
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
    new_sender = %Ekser.Node{message.sender | id: map.id}

    {:send,
     fn curr ->
       [Ekser.Message.Welcome.new(curr, new_sender, dht)]
     end}
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
