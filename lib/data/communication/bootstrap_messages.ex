defmodule Ekser.Message.Contact do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    Ekser.Node.create_from_json(payload)
  end

  @impl Ekser.Message
  def new(receivers, node) do
    fn curr ->
      for receiver <- receivers do
        Ekser.Message.new(__MODULE__, curr, receiver, [], node)
      end
    end
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.Message.SystemKnock.new([message.payload], 0)
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
    fn curr, bootstrap ->
      Ekser.Message.new(__MODULE__, curr, bootstrap, [], nil)
    end
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.Message.Contact.new(
      [message.sender],
      Ekser.Node.new(-1, message.sender.ip, message.sender.port, "", "")
    )
  end
end
