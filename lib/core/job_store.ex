defmodule Ekser.JobStore do
  use Agent

  # Client API

  def start_link(opts) do
    {jobs, just_opts} = Keyword.pop!(opts, :value)
    Agent.start_link(__MODULE__, :init, [jobs], just_opts)
  end

  def job_exists?(agent, job_name) do
    Agent.get(agent, __MODULE__, :has_job?, [job_name])
  end

  def get_job_by_name(agent, job_name) do
    Agent.get(agent, __MODULE__, :get_job, [job_name])
  end

  def receive_system(agent, system_jobs) do
    Agent.update(agent, __MODULE__, :merge_jobs, [system_jobs])
  end

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
