defmodule Ekser.Message.Leave do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  @impl Ekser.Message
  def new(_) do
    Ekser.Message.generate_bootstrap_closure(__MODULE__)
  end

  @impl Ekser.Message
  def send_effect(_) do
    :ok
  end
end

defmodule Ekser.Message.Join do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  @impl Ekser.Message
  def new(_) do
    Ekser.Message.generate_bootstrap_closure(__MODULE__)
  end

  @impl Ekser.Message
  def send_effect(_) do
    :ok
  end
end

defmodule Ekser.Message.Reject do
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

defmodule Ekser.Message.Contact do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_struct(payload, Ekser.Node) do
      true -> payload
      false -> Ekser.Node.create_from_json(payload)
    end
  end

  @impl Ekser.Message
  def new(receivers, node) do
    Ekser.Message.generate_receivers_closure(__MODULE__, receivers, node)
  end

  @impl Ekser.Message
  def send_effect(message) do
    case message.payload.id < 0 do
      true ->
        curr = %Ekser.Node{message.receiver | id: 0}
        :ok = Ekser.Router.update_curr(curr)
        :ok = Ekser.NodeStore.receive_node(curr)
        {:bootstrap, Ekser.Message.Join.new(nil)}

      false ->
        {:send, Ekser.Message.SystemKnock.new([message.payload], 0)}
    end
  end
end

defmodule Ekser.Message.Hail do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  @impl Ekser.Message
  def new(_) do
    Ekser.Message.generate_bootstrap_closure(__MODULE__)
  end

  @impl Ekser.Message
  def send_effect(message) do
    {:send,
     Ekser.Message.Contact.new(
       [message.sender],
       Ekser.Node.new(-1, message.sender.ip, message.sender.port, "", "")
     )}
  end
end
