defmodule Ekser.Message.Leave do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  def new(curr, bootstrap) do
    Ekser.Message.new(__MODULE__, curr, bootstrap, [], nil)
  end

  @impl Ekser.Message
  def send_effect(_) do
    :ok
  end
end

defmodule Ekser.Message.Join do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_struct(payload, Ekser.Node) do
      true -> payload
      false -> Ekser.Node.create_from_json(payload)
    end
  end

  def new(curr, bootstrap, node) do
    Ekser.Message.new(__MODULE__, curr, bootstrap, [], node)
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

  def new(curr, receiver) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
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

  def new(curr, receiver, node) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], node)
  end

  @impl Ekser.Message
  def send_effect(message) do
    case message.payload.id < 0 do
      true ->
        curr = %Ekser.Node{message.receiver | id: 0}
        :ok = Ekser.NodeStore.receive_node(curr)
        {:bootstrap, fn curr, bootstrap -> Ekser.Message.Join.new(curr, bootstrap, curr) end}

      false ->
        Ekser.Router.set_next(message.payload)
        {:send, fn curr -> [Ekser.Message.System_Knock.new(curr, message.payload)] end}
    end
  end
end

defmodule Ekser.Message.Hail do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  def new(curr, bootstrap) do
    Ekser.Message.new(__MODULE__, curr, bootstrap, [], nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    {:send,
     fn curr ->
       [
         Ekser.Message.Contact.new(
           curr,
           message.sender,
           Ekser.Node.new(-1, message.sender.ip, message.sender.port, "", "")
         )
       ]
     end}
  end
end
