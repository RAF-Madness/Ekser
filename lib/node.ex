defmodule Ekser.Node do
  require Ekser.Util

  defstruct [
    :id,
    :ip,
    :port
  ]

  defguard is_node(term) when is_struct(term, __MODULE__)

  def create_from_map(map) when is_map(map) do
    id = map["id"]
    ip = map["ipAddress"]
    port = map["port"]

    create(id, ip, port)
  end

  def create(id, ip, port) do
    with base <- new(),
         {:ok, ided} <- set_id(base, id),
         {:ok, iped} <- set_ip(ided, ip),
         {:ok, ported} <- set_port(iped, port) do
      {:ok, ported}
    else
      {:error, message} -> {:error, message}
    end
  end

  defp new() do
    %__MODULE__{}
  end

  defp set_id(node, id) when is_node(node) and is_integer(id) do
    {:ok, %__MODULE__{node | id: id}}
  end

  defp set_id(_, _) do
    {:error, "ID must be an integer."}
  end

  defp set_ip(node, ip) when is_node(node) and is_binary(ip) do
    {:ok, %__MODULE__{node | ip: ip}}
  end

  defp set_ip(_, _) do
    {:error, "IP must be a valid IP address."}
  end

  defp set_port(node, port) when is_node(node) and Ekser.Util.is_tcp_port(port) do
    {:ok, %__MODULE__{node | port: port}}
  end

  defp set_port(_, _) do
    {:error, Ekser.Util.port_prompt()}
  end
end
