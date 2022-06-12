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
    {port, just_opts} = Keyword.pop!(opts, :value)
    Supervisor.start_link(__MODULE__, port, just_opts)
  end

  @impl true
  def init(port) do
    sup_flags = %{
      strategy: :one_for_one,
      intensity: 1,
      period: 5,
      auto_shutdown: :any_significant
    }

    {:ok, {sup_flags, children(port)}}
  end

  defp children(port) do
    initial = add_parser()

    [
      Ekser.ListenerSup.child_spec(value: port, name: Ekser.ListenerSup),
      Ekser.Commander.child_spec(value: :stdio)
      | initial
    ]
  end

  defp add_parser() do
    input_file = Path.expand("input.txt")

    case File.exists?(input_file) do
      true ->
        [Ekser.Commander.child_spec(value: input_file)]

      false ->
        []
    end
  end
end
