defmodule Ekser.InputSup do
  require Ekser.Config
  use Supervisor

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      significant: true,
      shutdown: 5000,
      type: :supervisor
    }
  end

  def start_link(opts) do
    {config, just_opts} = Keyword.pop!(opts, :value)
    Supervisor.start_link(__MODULE__, config, just_opts)
  end

  @impl true
  def init(config) do
    sup_flags = %{
      strategy: :one_for_one,
      intensity: 1,
      period: 5,
      auto_shutdown: :any_significant
    }

    {:ok, {sup_flags, children(config)}}
  end

  defp children(config) do
    initial = add_parser(config.jobs)

    [
      Ekser.ListenerSup.child_spec(value: config.port, name: Ekser.ListenerSup),
      Ekser.Commander.child_spec(value: {:stdio, config.jobs})
      | initial
    ]
  end

  defp add_parser(jobs) do
    input_file = Path.expand("input.txt")

    case File.exists?(input_file) do
      true ->
        [Ekser.Commander.child_spec(value: {input_file, jobs})]

      false ->
        []
    end
  end
end
