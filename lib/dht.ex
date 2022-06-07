defmodule Ekser.DHT do
  require Ekser.Util
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

  defp new(bootstrap) when Ekser.Util.is_tcp_address(bootstrap) do
    %__MODULE__{bootstrap: bootstrap}
  end
end
