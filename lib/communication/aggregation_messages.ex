defmodule Ekser.Message.StartJob do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_struct(payload, Ekser.Result) do
      true -> payload
      false -> Ekser.Result.create_from_json(payload)
    end
  end

  def new(curr, receiver, result) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], result)
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.Aggregate.respond(message)
  end
end

defmodule Ekser.Message.StatusResponse do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_struct(payload, Ekser.Status) do
      true -> payload
      false -> Ekser.Status.create_from_json(payload)
    end
  end

  def new(curr, receiver, status) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], status)
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.Aggregate.respond(message)
  end
end

defmodule Ekser.Message.StatusRequest do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    nil
  end

  def new(curr, receiver, _) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    work_done = Ekser.FractalServer.status()
    {:send, fn curr -> [Ekser.Message.StatusResponse.new(curr, message.sender, work_done)] end}
  end
end

defmodule Ekser.Message.ResultResponse do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_struct(payload, Ekser.Result) do
      true -> payload
      false -> Ekser.Result.create_from_json(payload)
    end
  end

  def new(curr, receiver, result) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], result)
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.Aggregate.respond(message)
  end
end

defmodule Ekser.Message.ResultRequest do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(_) do
    nil
  end

  def new(curr, receiver, _) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    work_done = Ekser.FractalServer.result()
    {:send, fn curr -> [Ekser.Message.ResultResponse.new(curr, message.sender, work_done)] end}
  end
end

defmodule Ekser.Message.StoppedJobInfo do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_struct(payload, Ekser.Result) do
      true -> payload
      false -> Ekser.Result.create_from_json(payload)
    end
  end

  def new(curr, receiver, result) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], result)
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.Aggregate.respond(message)
  end
end

defmodule Ekser.Message.StopShareJob do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(nil) do
    nil
  end

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_struct(job, Ekser.Job) do
      true -> payload
      false -> Ekser.Job.create_from_json(payload)
    end
  end

  def new(curr, receiver, job) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], job)
  end

  @impl Ekser.Message
  def send_effect(message) do
    case message.payload do
      nil -> :ok
      job -> Ekser.JobStore.receive_job(message.payload)
    end

    work_done = Ekser.FractalServer.stop()
    {:send, fn curr -> [Ekser.Message.StoppedJobInfo.new(curr, message.sender, work_done)] end}
  end
end
