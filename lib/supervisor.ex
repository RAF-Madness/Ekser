defmodule Ekser.Supervisor do
  require Ekser.Config
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(_init_arg) do
    sup_flags = %{
      strategy: :one_for_one,
      intensity: 1,
      period: 5,
      auto_shutdown: :any_significant
    }

    {:ok, {sup_flags, get_children()}}
  end

  defp get_children() do
    config = Ekser.Config.read_config("config.json")

    initial = add_parser(config)

    [
      Task.Supervisor.child_spec(name: Ekser.Receiver.Supervisor),
      Ekser.TCPReceiver.child_spec([config.port]),
      Ekser.Commander.child_spec([config.jobs, :stdio])
      | initial
    ]
  end

  defp add_parser(config) do
    inputFile =
      "input.txt"
      |> Path.expand()

    readFromFile =
      inputFile
      |> File.exists?()

    case readFromFile do
      true ->
        [Ekser.Commander.child_spec([config.jobs, inputFile])]

      false ->
        []
    end
  end
end
