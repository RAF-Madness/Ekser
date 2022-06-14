defmodule Ekser.Listener do
  require Ekser.TCP
  require Ekser.Node
  require Ekser.Message
  require Logger
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

  def run(curr) do
    {:ok, socket} = :gen_tcp.listen(curr.port, Ekser.TCP.socket_options())
    # :ok = Ekser.Router.bootstrap(Ekser.Message.Hail.new(0))
    listen(socket, curr)
  end

  defp listen(socket, curr) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} =
      Task.Supervisor.start_child(Ekser.ReceiverSup, fn -> serve(client, curr, self()) end)

    :ok = :gen_tcp.controlling_process(client, pid)
    listen(socket, curr)
  end

  defp read(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp serve(socket, curr, pid) do
    bytes =
      socket
      |> read()

    :ok = :gen_tcp.close(socket)

    with {:ok, json} <- Jason.decode(bytes),
         message when not is_tuple(message) <- Ekser.Message.create_from_json(json) do
      process(message, curr, pid)
    else
      {:error, message} ->
        Logger.error(message)
    end
  end

  defp process(message, curr, pid) do
    case Ekser.Node.same_node?(message.receiver, curr) do
      true -> execute(message, pid)
      false -> Ekser.Router.forward(message)
    end
  end

  defp execute(message, pid) do
    effect = Ekser.Message.send_effect(message)

    case effect do
      :ok ->
        :ok

      :exit ->
        Process.exit(pid, :shutdown)

      {:bootstrap, closure} ->
        Ekser.Router.bootstrap(closure)

      {:send, closure} ->
        Ekser.Router.send(closure)
    end
  end
end
