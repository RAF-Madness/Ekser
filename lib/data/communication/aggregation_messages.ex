defmodule Ekser.Message.StatusResponse do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    Ekser.Status.create_from_json(payload)
  end

  @impl Ekser.Message
  def new(receivers, status) do
    Ekser.Message.generate_receivers_closure(__MODULE__, receivers, status)
  end

  @impl Ekser.Message
  def send_effect(message) do
    [{pid, _}] = Registry.lookup(Ekser.AggregateReg, message.payload.name)
    Ekser.StatusServ.respond(pid, message.sender.id, message.payload)
  end
end

defmodule Ekser.Message.StatusRequest do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_binary(payload) do
      true -> payload
      false -> {:error, "Payload is not a valid string."}
    end
  end

  @impl Ekser.Message
  def new(receivers, name) do
    Ekser.Message.generate_receivers_closure(__MODULE__, receivers, name)
  end

  @impl Ekser.Message
  def send_effect(message) do
    work_done = Ekser.FractalServ.get_work()
    {:send, Ekser.Message.StatusResponse.new([message.sender], work_done)}
  end
end

defmodule Ekser.Message.ResultResponse do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    Ekser.Result.create_from_json(payload)
  end

  @impl Ekser.Message
  def new(receivers, result) do
    Ekser.Message.generate_receivers_closure(__MODULE__, receivers, result)
  end

  @impl Ekser.Message
  def send_effect(message) do
    [{pid, _}] = Registry.lookup(Ekser.AggregateReg, message.payload.name)
    Ekser.ResultServ.respond(pid, message.sender.id, message.payload)
  end
end

defmodule Ekser.Message.ResultRequest do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_binary(payload) do
      true -> payload
      false -> {:error, "Payload is not a valid string."}
    end
  end

  @impl Ekser.Message
  def new(receivers, name) do
    Ekser.Message.generate_receivers_closure(__MODULE__, receivers, name)
  end

  @impl Ekser.Message
  def send_effect(message) do
    work_done = Ekser.FractalServ.get_work()
    {:send, Ekser.Message.ResultResponse.new([message.sender], work_done)}
  end
end
