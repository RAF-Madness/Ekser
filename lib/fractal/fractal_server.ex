defmodule Ekser.FractalServ do
  require Ekser.Job
  use GenServer

  # Client API

  @spec start(atom(), %Ekser.Job{}, String.t()) :: :ok | :error
  def start(server, job, fractal_id) do
    GenServer.call(server, {:start, job, fractal_id})
  end

  @spec start(atom(), %Ekser.Job{}) :: :ok | :error
  def start(server, job) do
    GenServer.call(server, {:start, job, "0"})
  end

  @spec stop(atom(), String.t()) :: :ok | :error
  def stop(server, job_name) do
    GenServer.call(server, {:stop, job_name})
  end

  def get_work(server) do
    GenServer.call(server, :work)
  end

  # Server Functions

  @impl GenServer
  def init(:ok) do
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:start, job, fractal_id}, _from, nil) do
    {:ok, agent} =
      DynamicSupervisor.start_child(
        Ekser.FractalSup,
        Ekser.FractalStore.child_spec(value: job.points, name: Ekser.FractalStore)
      )

    {:reply, :ok, {job, fractal_id, agent}}
  end

  @impl GenServer
  def handle_call({:start, _, _}, _from, {job, fractal_id, agent}) do
    {:reply, :error, {job, fractal_id, agent}}
  end

  @impl GenServer
  def handle_call({:stop, job_name}, _from, {job, fractal_id, agent}) do
    case job.name === job_name do
      true ->
        true = Process.exit(agent, :shutdown)
        {:reply, :ok, nil}

      false ->
        {:reply, :error, {job, fractal_id, agent}}
    end
  end

  @impl GenServer
  def handle_call({:stop, _}, _from, nil) do
    {:reply, :error, nil}
  end

  @impl GenServer
  def handle_call(:work, _from, nil) do
    {:reply, :error, nil}
  end
end
