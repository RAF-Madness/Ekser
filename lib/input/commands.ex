# ● status [X [id]] - Prikazuje stanje svih započetih izračunavanja - broj tačaka na
# svakom fraktalu. Naznačava za svaki fraktal koliko čvorova rade na njemu, fraktalni ID, i
# koliko tačaka je svaki čvor nacrtao. Ako se navede X kao naziv izračunavanja, onda se
# dohvata status samo za njega. Ako se navede posao i fraktalni ID, onda se dohvata status
# samo od čvora sa tim ID.
defmodule Ekser.Command.Status do
  require Ekser.Job
  require Ekser.Command
  @behaviour Ekser.Command

  @impl Ekser.Command
  def generate() do
    Ekser.Command.new(
      "status",
      &status/2,
      [
        {&Ekser.Command.resolve_job/2, true},
        {&Ekser.Command.resolve_id/2, true}
      ],
      "status [X [id]]"
    )
  end

  defp status([job, id], output) do
    GenServer.cast(Ekser.AggregateServ, {:status, [output, job.name, id]})
    "Attempting to collect status for job #{job.name} and fractal ID #{id}"
  end

  defp status([job], output) do
    GenServer.cast(Ekser.AggregateServ, {:status, [output, job.name]})
    "Attempting to collect status for job #{job.name}"
  end

  defp status([], output) do
    GenServer.cast(Ekser.AggregateServ, {:status, [output]})
    "Attempting to collect status for all jobs"
  end
end

# ● start [X] - Započinje izračunavanje za zadati posao X. X može da bude simboličko
# ime nekog posla navedenog u konfiguracionoj datoteci. Ako se X izostavi, pitati korisnika
# da unese parametre za posao na konzoli. Proveriti da je ime posla jedinstveno, kao i da su
# svi parametri validnih tipova. Ako je ovo K-ti posao u sistemu, neophodno je da ima makar
# K čvorova aktivno. Ako nema K čvorova aktivno, ne startovati posao.
defmodule Ekser.Command.Start do
  require Ekser.Job
  require Ekser.Command
  @behaviour Ekser.Command

  @impl Ekser.Command
  def generate() do
    Ekser.Command.new(
      "start",
      &start/2,
      [{&Ekser.Command.resolve_job/2, true}],
      "start [X]"
    )
  end

  defp start([job], _) do
    Ekser.FractalServ.start(Ekser.FractalServ, job)
    "Starting job #{job.name}"
  end

  defp start([], _) do
    {"Enter job parameters. Format: name N P WxH A1|A2|A3...", &parse_job/2}
  end

  defp parse_job(line, output) do
    read_job = Ekser.Job.create_from_line(line)

    case read_job do
      {:error, message} -> message
      job when is_struct(job, Ekser.Job) -> new_start(job, output)
    end
  end

  defp new_start(job, _) do
    case Ekser.JobStore.receive_job(job) do
      :unchanged -> "Job with name #{job.name} already exists."
      :ok -> Ekser.FractalServ.start(Ekser.FractalServ, job)
    end
  end
end

# ● result X [id] - Prikazuje rezultate za završeno izračunavanje za posao X. Korisnik
# može, a ne mora da navede fraktalni ID za rezultat. Ako se izostavi, onda se dohvata
# rezultat za ceo posao, u suprotnom samo za taj fraktalni ID. Slika treba da se eksportuje
# kao PNG.
defmodule Ekser.Command.Result do
  require Ekser.Job
  require Ekser.Command
  @behaviour Ekser.Command

  @impl Ekser.Command
  def generate() do
    Ekser.Command.new(
      "result",
      &result/2,
      [
        {&Ekser.Command.resolve_job/2, false},
        {&Ekser.Command.resolve_id/2, true}
      ],
      "result X [id]"
    )
  end

  defp result([job, id], output) do
    GenServer.cast(Ekser.AggregateServ, {:result, [output, job, id]})
    "Attempting to generate fractal image for job #{job.name} and fractal ID #{id}"
  end

  defp result([job], output) do
    GenServer.cast(Ekser.AggregateServ, {:result, [output, job]})
    "Attempting to generate fractal image for job #{job.name}"
  end
end

# ● stop X - Zaustavlja izračunavanje za posao X. Fraktal u potpunosti nestaje iz sistema, i
# čvorovi se preraspoređuju na druge poslove.
defmodule Ekser.Command.Stop do
  require Ekser.Job
  require Ekser.Command
  @behaviour Ekser.Command

  @impl Ekser.Command
  def generate() do
    Ekser.Command.new(
      "stop",
      &stop/2,
      [{&Ekser.Command.resolve_job/2, false}],
      "stop X"
    )
  end

  defp stop([job], _) do
    Ekser.FractalServ.stop(job.name)
    # send message to worker
    "Stopping job #{job.name}"
  end
end

# ● pause T - Čeka T milisekundi pre nego što pročita sledeću komandu.
defmodule Ekser.Command.Pause do
  require Ekser.Command
  @behaviour Ekser.Command

  @impl Ekser.Command
  def generate() do
    Ekser.Command.new(
      "pause",
      &pause/2,
      [{&Ekser.Command.resolve_milliseconds/2, false}],
      "pause T"
    )
  end

  defp pause([milliseconds], _) do
    Process.sleep(milliseconds)
    "Successfully slept for #{milliseconds} milliseconds"
  end
end

# ● quit - Uredno gašenje čvora
defmodule Ekser.Command.Quit do
  require Ekser.Command
  @behaviour Ekser.Command

  @impl Ekser.Command
  def generate() do
    Ekser.Command.new(
      "quit",
      &quit/2,
      [],
      "quit"
    )
  end

  defp quit([], _) do
    exit(:shutdown)
  end
end
