defmodule Ekser.FractalStore do
  use Agent, restart: :transient

  # Client API

  def start_link(opts) do
    {points, just_opts} = Keyword.pop!(opts, :value)
    Agent.start_link(Ekser.FractalStore, :init, [points], just_opts)
  end

  # Agent Functions

  def init(points) do
    points
  end
end
