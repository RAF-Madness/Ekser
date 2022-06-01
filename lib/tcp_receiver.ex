defmodule TCPReceiver do
  def init(port) do
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
