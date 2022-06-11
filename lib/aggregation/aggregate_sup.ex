defmodule Ekser.AggregateSup do
  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(child_spec, name) do
    DynamicSupervisor.start_child(name, child_spec)
  end
end
