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

    ip =
      System.cmd("nslookup", ["myip.opendns.com", "resolver1.opendns.com"])
      |> elem(0)
      |> String.split()
      |> Enum.at(7)
      |> Ekser.TCP.to_ip()

    curr = Ekser.Node.new(-2, ip, config.port, "", "")

    [
      Task.Supervisor.child_spec(name: Ekser.SenderSup),
      Ekser.Router.child_spec(name: Ekser.Router),
      Ekser.DHTStore.child_spec(value: curr, name: Ekser.DHTStore),
      Ekser.JobStore.child_spec(value: config.jobs, name: Ekser.JobStore),
      Ekser.FractalServ.child_spec(name: Ekser.FractalServ),
      Ekser.FractalSup.child_spec(name: Ekser.FractalSup),
      Ekser.AggregateSup.child_spec(name: Ekser.AggregateSup),
      Registry.child_spec(keys: :unique, name: AggregatorRegistry),
      Ekser.AggregateServ.child_spec(name: Ekser.AggregateServ),
      Ekser.InputSup.child_spec(value: config, name: Ekser.InputSup)
    ]
  end
end
