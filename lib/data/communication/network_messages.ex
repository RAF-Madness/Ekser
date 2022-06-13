defmodule Ekser.Message.Entered do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  @impl Ekser.Message
  def new(receivers, _) do
    Ekser.Message.generate_receivers_closure(__MODULE__, receivers, nil)
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

  @impl Ekser.Message
  def new(receivers, _) do
    Ekser.Message.generate_receivers_closure(__MODULE__, receivers, nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    :ok = Ekser.Router.set_next(message.sender)

    {curr, nodes} =
      Ekser.NodeStore.get_nodes([])
      |> Map.pop!(:curr)

    closure =
      nodes
      |> Map.pop(curr.id)
      |> elem(1)
      |> Map.values()
      |> Ekser.Message.Entered.new(nil)

    {:send, closure}
  end
end

defmodule Ekser.Message.ConnectionRequest do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  @impl Ekser.Message
  def new(receivers, _) do
    Ekser.Message.generate_receivers_closure(__MODULE__, receivers, nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    :ok = Ekser.Router.set_prev(message.sender)
    {:send, Ekser.Message.ConnectionResponse.new([message.sender], 0)}
  end
end

defmodule Ekser.Message.Welcome do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    Ekser.DHT.create_from_json(payload)
  end

  @impl Ekser.Message
  def new(receivers, dht) do
    Ekser.Message.generate_receivers_closure(__MODULE__, receivers, dht)
  end

  @impl Ekser.Message
  def send_effect(message) do
    :ok = Ekser.Router.set_prev(message.sender)
    :ok = Ekser.JobStore.receive_system(message.payload)

    first_node = Ekser.NodeStore.receive_system(message.payload)

    {:send, Ekser.Message.ConnectionRequest.new([first_node], 0)}
  end
end

defmodule Ekser.Message.SystemKnock do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  @impl Ekser.Message
  def new(receivers, _) do
    Ekser.Message.generate_receivers_closure(__MODULE__, receivers, nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    :ok = Ekser.Router.introduce_new(message.sender)
    map = Ekser.NodeStore.introduce_new()
    jobs = Ekser.JobStore.get_all_jobs()
    dht = Ekser.DHT.new(map.id, map.nodes, jobs)
    {:send, Ekser.Message.Welcome.new(message.sender, dht)}
  end
end

defmodule Ekser.Message.Quit do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  @impl Ekser.Message
  def new(receivers, _) do
    Ekser.Message.generate_receivers_closure(__MODULE__, receivers, nil)
  end

  @impl Ekser.Message
  def send_effect(_) do
    :exit
  end
end

defmodule Ekser.Message.Quit do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  @impl Ekser.Message
  def new(receivers, _) do
    Ekser.Message.generate_receivers_closure(__MODULE__, receivers, nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.NodeStore.leave_network(message.sender)
  end
end
