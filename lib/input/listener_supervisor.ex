defmodule Ekser.ListenerSup do
  require Ekser.TCP
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
      strategy: :rest_for_one,
      intensity: 1,
      period: 5,
      auto_shutdown: :any_significant
    }

    :ok =
      Ekser.Router.bootstrap(fn curr, bootstrap -> Ekser.Message.Hail.new(curr, bootstrap) end)

    {:ok, {sup_flags, children(curr)}}
  end

  defp children(curr) do
    [
      Task.Supervisor.child_spec(name: Ekser.ReceiverSup),
      Ekser.Listener.child_spec(value: curr)
    ]
  end
end
