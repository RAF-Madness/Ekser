defmodule Ekser.FractalCruncher do
  use Task

  def start_link(args) do
    Task.start_link(__MODULE__, :run, args)
  end

  def run(ratio, anchor_points, last_point) do
    next_point = Ekser.Point.next_point(ratio, anchor_points, last_point)
    Ekser.FractalServer.receive_point(next_point)
    run(ratio, anchor_points, next_point)
  end
end
