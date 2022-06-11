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

  def start_link(port, opts) when Ekser.TCP.is_tcp_port(port) and is_list(opts) do
    {port, just_opts} = Keyword.pop!(opts, :value)
    Supervisor.start_link(__MODULE__, port, just_opts)
  end

  @impl true
  def init(port) do
    sup_flags = %{
      strategy: :rest_for_one,
      intensity: 1,
      period: 5,
      auto_shutdown: :any_significant
    }

    {:ok, {sup_flags, children(port)}}
  end

  defp children(port) do
    [
      Task.Supervisor.child_spec(name: Ekser.MessageSup),
      Ekser.Listener.child_spec(value: port)
    ]
  end
end
