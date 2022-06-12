defmodule Ekser.Message.Entered do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  @impl Ekser.Message
  def new(receivers, _) do
    fn curr ->
      for receiver <- receivers do
        Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
      end
    end
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.DHTStore.enter_network(Ekser.DHTStore, message.sender)
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
    fn curr ->
      for receiver <- receivers do
        Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
      end
    end
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.Router.set_next(Ekser.Router, message.sender)

    [Ekser.DHTStore.get_all_nodes(Ekser.DHTStore)]
    |> Ekser.Message.Entered.new(0)
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
    fn curr ->
      for receiver <- receivers do
        Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
      end
    end
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.Router.set_prev(Ekser.Router, message.sender)
    Ekser.Message.ConnectionResponse.new([message.sender], 0)
  end
end

defmodule Ekser.Message.Welcome do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    Ekser.DHT.create_from_json(payload)
  end

  @impl Ekser.Message
  def new(receivers, _) do
    partial_dht = Ekser.DHTStore.introduce_new(Ekser.DHTStore)

    payload =
      Ekser.DHT.new(
        partial_dht.id,
        partial_dht.nodes,
        Ekser.JobStore.get_all_jobs(Ekser.JobStore)
      )

    fn curr ->
      for receiver <- receivers do
        Ekser.Message.new(__MODULE__, curr, receiver, [], payload)
      end
    end
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.Router.receive_contact(Ekser.Router, message.sender)

    Ekser.JobStore.receive_system(Ekser.JobStore, message.payload)

    first_node =
      Ekser.DHTStore.receive_system(
        Ekser.DHTStore,
        message.payload
      )

    Ekser.Message.ConnectionRequest.new([first_node], 0)
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
    fn curr ->
      for receiver <- receivers do
        Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
      end
    end
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.Router.introduce_new(Ekser.Router, message.sender)
    Ekser.Message.Welcome.new(message.sender, 0)
  end
end

defmodule Ekser.Message.Leave do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  @impl Ekser.Message
  def new(receivers, _) do
    fn curr ->
      for receiver <- receivers do
        Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
      end
    end
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.DHTStore.leave_network(Ekser.DHTStore, message.sender)
  end
end
