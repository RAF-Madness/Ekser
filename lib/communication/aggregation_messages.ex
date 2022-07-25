defmodule Ekser.Message.Start_Job do
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
    Ekser.FractalServer.start_job(message.payload.points)
  end
end

defmodule Ekser.Message.Status_Response do
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

defmodule Ekser.Message.Status_Request do
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
    work_done = Ekser.FractalServer.status()
    {:send, fn curr -> [Ekser.Message.Status_Response.new(curr, message.sender, work_done)] end}
  end
end

defmodule Ekser.Message.Result_Response do
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

defmodule Ekser.Message.Result_Request do
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
    {:send, fn curr -> [Ekser.Message.Result_Response.new(curr, message.sender, work_done)] end}
  end
end

defmodule Ekser.Message.Stopped_Job_Info do
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

defmodule Ekser.Message.Stop_Share_Job do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(nil) do
    nil
  end

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_struct(payload, Ekser.Job) do
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
      _ -> Ekser.JobStore.receive_job(message.payload)
    end

    work_done = Ekser.FractalServer.stop()
    {:send, fn curr -> [Ekser.Message.Stopped_Job_Info.new(curr, message.sender, work_done)] end}
  end
end
