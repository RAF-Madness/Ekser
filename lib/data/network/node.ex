defmodule Ekser.Node do
  require Ekser.TCP
  @behaviour Ekser.Serializable

  @enforce_keys [:ip, :port]
  defstruct [
    :id,
    :ip,
    :port
  ]

  defguard is_node(term) when is_struct(term, __MODULE__)

  @impl Ekser.Serializable
  def create_from_json(json) when is_map(json) do
    id = json["nodeId"]
    ip = json["ipAddress"]
    port = json["port"]

    new(id, ip, port)
  end

  @impl Ekser.Serializable
  def get_kv(struct) when is_node(struct) do
    {struct.id, struct}
  end

  def new(id, ip, port) do
    with {:id, true} <- {:id, is_integer(id)},
         {:ip, true} <- {:ip, Ekser.TCP.is_tcp_ip(ip)},
         {:port, true} <- {:port, Ekser.TCP.is_tcp_port(port)} do
      {:ok, %__MODULE__{id: id, ip: ip, port: port}}
    else
      {:id, false} ->
        {:error, "Node ID must be an integer."}

      {:ip, false} ->
        {:error,
         "Node IP must be a valid IP address represented as a tuple of separate integers."}

      {:port, false} ->
        {:error, Ekser.TCP.port_prompt()}
    end
  end
end

defimpl Jason.Encoder, for: Ekser.Node do
  def encode(value, opts) do
    map = %{id: value.id, ip: Ekser.TCP.from_ip(value.ip), port: value.port}

    Jason.Encode.map(map, opts)
  end
end
