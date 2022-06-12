defmodule Ekser.Node do
  require Ekser.TCP
  @behaviour Ekser.Serializable

  @enforce_keys [:ip, :port]
  defstruct [
    :id,
    :ip,
    :port,
    :fractal_id,
    :job_name
  ]

  defguard is_node(term) when is_struct(term, __MODULE__)

  @impl Ekser.Serializable
  def create_from_json(json) when is_map(json) do
    id = json["nodeId"]

    ip =
      json["ipAddress"]
      |> Ekser.TCP.to_ip()

    port = json["port"]
    fractal_id = json["fractalId"]
    job_name = json["jobName"]

    new(id, ip, port, fractal_id, job_name)
  end

  @impl Ekser.Serializable
  def get_kv(struct) when is_node(struct) do
    {struct.id, struct}
  end

  def new(id, ip, port, fractal_id, job_name) do
    with {true, _} <- {is_integer(id), "Node ID must be an integer."},
         {true, _} <-
           {Ekser.TCP.is_tcp_ip(ip),
            "Node IP must be a valid IP address represented as a tuple of integers."},
         {true, _} <- {Ekser.TCP.is_tcp_port(port), Ekser.TCP.port_prompt()},
         {true, _} <- {is_binary(fractal_id), "Fractal ID must be a string."},
         {true, _} <- {is_binary(job_name), "Job name must be a string."} do
      {:ok, %__MODULE__{id: id, ip: ip, port: port, fractal_id: fractal_id, job_name: job_name}}
    else
      {false, message} ->
        {:error, message}
    end
  end

  def equal?(node1, node2) when is_node(node1) and is_node(node2) do
    node1.id === node2.id or (node1.ip === node2.ip and node1.port === node2.port)
  end
end

defimpl Jason.Encoder, for: Ekser.Node do
  def encode(value, opts) do
    map = %{Map.from_struct(value) | ip: Ekser.TCP.from_ip(value.ip)}

    Jason.Encode.map(map, opts)
  end
end
