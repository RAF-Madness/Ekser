defmodule Ekser.TCPReceiver do
  require Ekser.Util
  use Task

  def child_spec([port]) when Ekser.Util.is_tcp_port(port) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [port]},
      restart: :transient,
      significant: true,
      shutdown: 5000,
      type: :worker
    }
  end

  def start_link([port]) when Ekser.Util.is_tcp_port(port) do
    Task.start_link(__MODULE__, :run, [port])
  end

  def run(port) when Ekser.Util.is_tcp_port(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true])
    listen(socket)
  end

  defp listen(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Ekser.Receiver.Supervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    listen(socket)
  end

  defp serve(socket) do
    socket
    |> read()
    |> Jason.decode!()
    |> Ekser.Message.create_from_json()
  end

  defp read(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end
end
