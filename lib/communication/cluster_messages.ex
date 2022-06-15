defmodule Ekser.Message.EnteredCluster do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_struct(payload, Ekser.Node) do
      true -> payload
      false -> Ekser.Node.create_from_json(payload)
    end
  end

  def new(curr, receiver, node) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], payload)
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.NodeStore.receive_node(message.payload)
  end
end

defmodule Ekser.Message.ClusterConnectionResponse do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    nil
  end

  def new(curr, receiver) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], nil)
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.Router.add_cluster_neighbour(message.sender)
  end
end

defmodule Ekser.Message.ClusterConnectionRequest do
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
    Ekser.Router.add_cluster_neighbour(message.sender)
    {:send, fn curr -> Ekser.ClusterConnectionResponse.new(curr, message.sender) end}
  end
end

defmodule Ekser.Message.ClusterWelcome do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    case is_struct(payload, Ekser.Node) do
      true -> payload
      false -> Ekser.Node.create_from_json(payload)
    end
  end

  def new(curr, receiver, node) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], payload)
  end

  @impl Ekser.Message
  def send_effect(message) do
    Ekser.NodeStore.receive_node(message.payload)
  end
end

defmodule Ekser.Message.ClusterKnock do
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
    case Ekser.NodeStore.get_next_fractal_id() do
      :error -> :ok
      fractal_id -> fn curr -> Ekser.ClusterWelcome.new(curr, message.sender, fractal_id) end
    end
  end
end

defmodule Ekser.Message.ApproachCluster do
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
    {:send, fn curr -> Ekser.Message.ClusterKnock.new(curr, receiver) end}
  end
end

defmodule Ekser.Message.StartJobGenesis do
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
    job = Ekser.JobStore.get_job_by_name(message.payload.job_name)
    Ekser.FractalServer.join_cluster(job, "0")
    Ekser.FractalServer.start_job(payload.points)
    new_curr = %Ekser.Node{curr | job_name: job.name, fractal_id: "0"}
    Ekser.NodeStore.receive_node(new_curr)
    Ekser.Router.update_curr(new_curr)

    receivers = Ekser.NodeStore.get_nodes([])

    {:send,
     fn curr ->
       Enum.map(receivers, fn receiver ->
         Ekser.Message.EnteredCluster.new(curr, receiver, new_curr)
       end)
     end}
  end
end
