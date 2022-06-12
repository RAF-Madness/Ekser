defmodule Ekser.Listener do
  require Ekser.TCP
  require Ekser.Message
  use Task

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      significant: true,
      shutdown: 5000,
      type: :worker
    }
  end

  def start_link(opts) do
    {port, _} = Keyword.pop!(opts, :value)
    Task.start_link(__MODULE__, :run, [port])
  end

  def run(port) when Ekser.TCP.is_tcp_port(port) do
    {:ok, socket} = :gen_tcp.listen(port, Ekser.TCP.socket_options())
    listen(socket)
  end

  defp listen(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Ekser.ReceiverSup, fn -> serve(client, self()) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    listen(socket)
  end

  defp serve(socket, _) do
    utf =
      socket
      |> read()

    :ok = :gen_tcp.close(socket)

    message =
      utf
      |> Jason.decode!()
      |> Ekser.Message.create_from_json()
      |> Ekser.Message.send_effect()

    case message do
      :ok ->
        :ok

      closure when is_function(closure) ->
        Ekser.Router.send(Ekser.Router, closure)

      message when Ekser.Message.is_message(message) ->
        Ekser.Router.forward(Ekser.Router, message)
    end
  end

  defp read(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end
end
