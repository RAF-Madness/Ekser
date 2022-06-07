defmodule Ekser.DHT do
  require Ekser.Node
  use Agent

  defstruct [
    :bootstrap,
    :prev,
    :curr,
    :next,
    nodes: []
  ]

  def start_link(bootstrap) do
    Agent.start_link(fn -> new(bootstrap) end)
  end

  defp new(bootstrap) when Ekser.Node.is_node(bootstrap) do
    %__MODULE__{bootstrap: bootstrap}
  end
end
