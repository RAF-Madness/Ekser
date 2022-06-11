defmodule Ekser.Sender do
  require Ekser.TCP
  require Ekser.Message
  require Ekser.DHT
  use GenServer

  # Client API

  def hail() do
    keys = [:bootstrap, :curr]
    # values = Ekser.DHT.get_from_dht(Ekser.DHT, keys)
  end

  # Server Functions

  @impl true
  def init(:ok) do
    {:ok, 0}
  end

  defp send_message(message) when Ekser.Message.is_message(message) do
    {:ok, socket} =
      :gen_tcp.connect(message.receiver.ip, message.receiver.port, Ekser.TCP.socket_options())

    :gen_tcp.send(socket, Jason.encode!(message))
  end
end
