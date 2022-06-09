defmodule Ekser.FractalServ do
  require Ekser.Job
  use GenServer

  defstruct [
    :fractal_id,
    :cluster_nodes,
    :neighbouring_cluster_node,
    :job
  ]

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end
end
