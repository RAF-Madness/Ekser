defmodule Ekser.Supervisor do
  require Ekser.Config
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    log_file = Path.expand("log.txt")

    File.write!(log_file, "")

    Logger.add_backend({LoggerFileBackend, :log})

    Logger.configure_backend({LoggerFileBackend, :log},
      path: log_file
    )

    sup_flags = %{
      strategy: :one_for_one,
      intensity: 1,
      period: 5,
      auto_shutdown: :any_significant
    }

    {:ok, {sup_flags, children()}}
  end

  defp children() do
    config = Ekser.Config.read_config("config.json")

    [
      Ekser.DHT.child_spec(value: {config.port, config.bootstrap}, name: Ekser.DHT),
      Task.Supervisor.child_spec(name: Ekser.SenderSup),
      Ekser.Sender.child_spec(name: Ekser.Sender),
      Ekser.FractalServ.child_spec(name: Ekser.FractalServ),
      Ekser.FractalSup.child_spec(name: Ekser.FractalSup),
      Ekser.InputSup.child_spec(value: config, name: Ekser.InputSup)
    ]
  end
end
