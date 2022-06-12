defmodule Ekser.FractalServ do
  require Ekser.Job
  use GenServer

  # Client API

  def start(server, job, fractal_id) do
    GenServer.call(server, {:start, job, fractal_id})
  end

  def start(server, job) do
    GenServer.call(server, {:start, job, "0"})
  end

  def stop(server, job_name) do
    GenServer.call(server, {:stop, job_name})
  end

  # Server Functions

  @impl GenServer
  def init(:ok) do
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:start, job, fractal_id}, _from, nil) do
    {:reply, :ok, {job, fractal_id}}
  end

  @impl GenServer
  def handle_call({:start, _, _}, _from, {job, fractal_id}) do
    {:reply, :error, {job, fractal_id}}
  end

  @impl GenServer
  def handle_call({:stop, job_name}, _from, {job, fractal_id}) do
    case job.name === job_name do
      true -> {:reply, :ok, nil}
      false -> {:reply, :error, {job, fractal_id}}
    end
  end

  @impl GenServer
  def handle_call({:stop, _}, _from, nil) do
    {:reply, :error, nil}
  end
end
