defmodule Ekser.AggregateServ do
  require Ekser.AggregateSup
  require Ekser.StatusServ
  require Ekser.ResultServ
  use GenServer

  # Client API

  def start_status(server, args) do
    GenServer.cast(server, {:status, args})
  end

  def start_result(server, args) do
    GenServer.cast(server, {:result, args})
  end

  # Server Functions

  @impl GenServer
  def init(:ok) do
    {:ok, {0, 0}}
  end

  @impl GenServer
  def handle_cast({:status, args}, {status, result}) do
    Ekser.StatusServ.child_spec([status | args])
    |> Ekser.AggregateSup.start_child(Ekser.AggregateSup)

    {:noreply, {status + 1, result}}
  end

  @impl GenServer
  def handle_cast({:result, args}, {status, result}) do
    Ekser.ResultServ.child_spec([result | args])
    |> Ekser.AggregateSup.start_child(Ekser.AggregateSup)

    {:noreply, {status, result + 1}}
  end
end
