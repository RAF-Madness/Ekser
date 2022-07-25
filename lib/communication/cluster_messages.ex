defmodule Ekser.Message.Updated_Node do
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
    Ekser.NodeStore.receive_node(message.payload)
    :ok
  end
end

defmodule Ekser.Message.Entered_Cluster do
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
    Ekser.NodeStore.receive_node(message.payload)
    Ekser.Aggregate.respond_job(message)
    :ok
  end
end

defmodule Ekser.Message.Cluster_Connection_Response do
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
    Ekser.Aggregate.respond(message)
  end
end

defmodule Ekser.Message.Cluster_Connection_Request do
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
    Ekser.Router.add_cluster_neighbour(message.sender)
    {:send, fn curr -> [Ekser.Message.Cluster_Connection_Response.new(curr, message.sender)] end}
  end
end

defmodule Ekser.Message.Cluster_Welcome do
  @behaviour Ekser.Message

  @impl Ekser.Message
  def parse_payload(payload) do
    with fractal_id when fractal_id != nil <- payload["fractal_id"],
         job_name when job_name != nil <- payload["job_name"],
         true <- Ekser.FractalId.valid_fractal_id?(fractal_id),
         true <- is_binary(job_name) do
      payload
    else
      _ -> :error
    end
  end

  def new(curr, receiver, {job_name, fractal_id}) do
    Ekser.Message.new(__MODULE__, curr, receiver, [], %{
      "job_name" => job_name,
      "fractal_id" => fractal_id
    })
  end

  @impl Ekser.Message
  def send_effect(message) do
    job = Ekser.JobStore.get_job_by_name(message.payload["job_name"])
    Ekser.FractalServer.join_cluster(job, message.payload["fractal_id"])

    Ekser.ClusterServer.child_spec([message.payload["job_name"], message.payload["fractal_id"]])
    |> Ekser.Aggregate.new()

    :ok
  end
end

defmodule Ekser.Message.Cluster_Knock do
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
    case Ekser.NodeStore.get_next_fractal_id(message.sender) do
      :error ->
        :ok

      fractal_id ->
        {:send,
         fn curr ->
           [Ekser.Message.Cluster_Welcome.new(curr, message.sender, {curr.job_name, fractal_id})]
         end}
    end
  end
end

defmodule Ekser.Message.Approach_Cluster do
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
    Ekser.Router.wipe_cluster_neighbours()
    {:send, fn curr -> [Ekser.Message.Cluster_Knock.new(curr, message.payload)] end}
  end
end

defmodule Ekser.Message.Start_Job_Genesis do
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
    Ekser.Router.wipe_cluster_neighbours()
    Ekser.FractalServer.join_cluster(job, "0")
    Ekser.FractalServer.start_job(message.payload.points)

    all_nodes = Ekser.NodeStore.get_nodes([])
    {curr, nodes_without_curr} = Map.pop(all_nodes, :curr)

    receivers =
      nodes_without_curr
      |> Map.pop(curr.id)
      |> elem(1)
      |> Map.values()

    {:send,
     fn curr ->
       Enum.map(receivers, fn receiver ->
         Ekser.Message.Entered_Cluster.new(curr, receiver, curr)
       end)
     end}
  end
end
