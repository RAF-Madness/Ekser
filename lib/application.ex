defmodule Ekser do
  use Application

  @impl true
  def start(_type, _args) do
    Ekser.Supervisor.start_link(name: Ekser.Supervisor)
  end
end
