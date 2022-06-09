defmodule Ekser.Sender do
  require Ekser.Util
  require Ekser.DHT
  use GenServer

  # Client API

  def hail() do
    keys = [:bootstrap, :curr]
    values = Ekser.DHT.get_from_dht(Ekser.DHT, keys)
  end

  # Server Functions

  @impl true
  def init(:ok) do
    {:ok, 0}
  end

  defp send_message(message) when Ekser.Message.is_message(message) do
    json =
      Ekser.Message.prepare_for_json(message)
      |> Jason.encode!()

    {:ok, socket} =
      :gen_tcp.connect(message.receiver.ip, message.receiver.port, Ekser.Util.socket_options())

    :gen_tcp.send(socket, json)
  end
end
