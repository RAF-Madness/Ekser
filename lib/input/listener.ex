defmodule Ekser.Listener do
  require Ekser.TCP
  require Ekser.Node
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
    {curr, _} = Keyword.pop!(opts, :value)
    Task.start_link(__MODULE__, :run, [curr])
  end

  def run(curr) when Ekser.Node.is_node(curr) do
    {:ok, socket} = :gen_tcp.listen(curr.port, Ekser.TCP.socket_options())
    :ok = Ekser.Router.send(Ekser.Router, Ekser.Message.Hail.new(0))
    listen(socket, curr)
  end

  defp listen(socket, curr) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} =
      Task.Supervisor.start_child(Ekser.ReceiverSup, fn -> serve(client, curr, self()) end)

    :ok = :gen_tcp.controlling_process(client, pid)
    listen(socket, curr)
  end

  defp serve(socket, curr, pid) do
    utf =
      socket
      |> read()

    :ok = :gen_tcp.close(socket)

    message =
      utf
      |> Jason.decode!()
      |> Ekser.Message.create_from_json()

    case Ekser.Node.equal?(message.receiver, curr) do
      true -> process(message, pid)
      false -> Ekser.Router.forward(Ekser.Router, message)
    end
  end

  defp process(message, pid) do
    effect = Ekser.Message.send_effect(message)

    case effect do
      :ok ->
        :ok

      :exit ->
        Process.exit(pid, :shutdown)

      closure when is_function(closure) ->
        Ekser.Router.send(Ekser.Router, closure)
    end
  end

  defp read(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end
end
