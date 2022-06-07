defmodule Ekser.TCPReceiver do
  require Ekser.Util
  use Task

  def child_spec(port) when Ekser.Util.is_tcp_port(port) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [port]},
      restart: :transient,
      significant: true,
      shutdown: 5000,
      type: :worker
    }
  end

  def start_link(port) when Ekser.Util.is_tcp_port(port) do
    Task.start_link(__MODULE__, :run, [port])
  end

  def run(port) when Ekser.Util.is_tcp_port(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true])
    listen(socket)
  end

  defp listen(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    serve(client)
    listen(socket)
  end

  defp serve(socket) do
    socket
    |> read()
    |> deserialize_json()
  end

  defp read(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp deserialize_json(data) do
    Jason.decode!(data)
  end
end
