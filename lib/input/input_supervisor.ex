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
    {curr, just_opts} = Keyword.pop!(opts, :value)
    Supervisor.start_link(__MODULE__, curr, just_opts)
  end

  @impl Supervisor
  def init(curr) do
    sup_flags = %{
      strategy: :one_for_one,
      intensity: 0,
      period: 5,
      auto_shutdown: :any_significant
    }

    {:ok, {sup_flags, children(curr)}}
  end

  defp children(curr) do
    initial = add_parser()

    [
      Ekser.ListenerSup.child_spec(value: curr, name: Ekser.ListenerSup),
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
