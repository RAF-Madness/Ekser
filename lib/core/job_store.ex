defmodule Ekser.JobStore do
  require Ekser.DHT
  use Agent

  # Client API

  def start_link(opts) do
    {jobs, just_opts} = Keyword.pop!(opts, :value)
    Agent.start_link(__MODULE__, :init, [jobs], just_opts)
  end

  @spec get_all_jobs(atom()) :: %{String.t() => %Ekser.Job{}}
  def get_all_jobs(agent) do
    Agent.get(agent, __MODULE__, :get_jobs, [])
  end

  @spec job_exists?(atom(), String.t()) :: boolean()
  def job_exists?(agent, job_name) do
    Agent.get(agent, __MODULE__, :has_job?, [job_name])
  end

  @spec get_job_by_name(atom(), String.t()) :: %Ekser.Job{} | nil
  def get_job_by_name(agent, job_name) do
    Agent.get(agent, __MODULE__, :get_job, [job_name])
  end

  @spec receive_system(atom(), %Ekser.DHT{}) :: :ok
  def receive_system(agent, dht) do
    Agent.update(agent, __MODULE__, :merge_jobs, [dht.jobs])
  end

  @spec receive_job(atom(), %Ekser.Job{}) :: :ok | :error
  def receive_job(agent, job) do
    Agent.get_and_update(agent, __MODULE__, :add_job, [job])
  end

  # Server Functions

  def init(jobs) do
    jobs
  end

  def has_job?(jobs, job_name) do
    Map.has_key?(jobs, job_name)
  end

  def get_jobs(jobs) do
    jobs
  end

  def get_job(jobs, job_name) do
    Enum.find(jobs, fn element -> element.name === job_name end)
  end

  def add_job(jobs, job) do
    case has_job?(jobs, job.name) do
      true -> {:error, jobs}
      false -> {:ok, Map.put(jobs, job.name, job)}
    end
  end

  def merge_jobs(jobs, new_jobs) do
    Map.merge(jobs, new_jobs)
  end
end
