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

    basic = [
      Ekser.Commander.child_spec(config.jobs, :stdio),
      Ekser.TCPReceiver.child_spec(config.port)
    ]

    append_parsers(config, basic)
  end

  defp append_parsers(config, children) do
    inputFile =
      "input.txt"
      |> Path.expand()

    readFromFile =
      inputFile
      |> File.exists?()

    case readFromFile do
      true ->
        [Ekser.Commander.child_spec(config.jobs, inputFile) | children]

      false ->
        children
    end
  end
end
