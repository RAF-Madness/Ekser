# ● status [X [id]] - Prikazuje stanje svih započetih izračunavanja - broj tačaka na
# svakom fraktalu. Naznačava za svaki fraktal koliko čvorova rade na njemu, fraktalni ID, i
# koliko tačaka je svaki čvor nacrtao. Ako se navede X kao naziv izračunavanja, onda se
# dohvata status samo za njega. Ako se navede posao i fraktalni ID, onda se dohvata status
# samo od čvora sa tim ID.
# ● start [X] - Započinje izračunavanje za zadati posao X. X može da bude simboličko
# ime nekog posla navedenog u konfiguracionoj datoteci. Ako se X izostavi, pitati korisnika
# da unese parametre za posao na konzoli. Proveriti da je ime posla jedinstveno, kao i da su
# svi parametri validnih tipova. Ako je ovo K-ti posao u sistemu, neophodno je da ima makar
# K čvorova aktivno. Ako nema K čvorova aktivno, ne startovati posao.
# ● result X [id] - Prikazuje rezultate za završeno izračunavanje za posao X. Korisnik
# može, a ne mora da navede fraktalni ID za rezultat. Ako se izostavi, onda se dohvata
# rezultat za ceo posao, u suprotnom samo za taj fraktalni ID. Slika treba da se eksportuje
# kao PNG.
# ● stop X - Zaustavlja izračunavanje za posao X. Fraktal u potpunosti nestaje iz sistema, i
# čvorovi se preraspoređuju na druge poslove.
# ● pause T - Čeka T milisekundi pre nego što pročita sledeću komandu.
# ● quit - Uredno gašenje čvora
defmodule Ekser.Commander do
  require Ekser.Command
  require Ekser.Job
  use Task

  def child_spec(opts = [value: {filename, _}]) do
    id =
      case filename do
        :stdio -> CLI
        _ -> FI
      end

    %{
      id: id,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      significant: true,
      shutdown: 5000,
      type: :worker
    }
  end

  def start_link(opts) do
    {{filename, jobs}, _} = Keyword.pop!(opts, :value)
    Task.start_link(__MODULE__, :run, [filename, jobs])
  end

  def run(:stdio, jobs) do
    init(:stdio, :stdio, jobs)
  end

  def run(filename, jobs) do
    filepath = Path.expand(filename)
    input = File.open!(filepath, [:read, :utf8])

    output = Path.dirname(filepath) |> Path.join("output.txt") |> File.open!([:write, :utf8])

    init(input, output, jobs)
  end

  defp init(input, output, jobs) do
    true = Enum.all?(jobs, fn element -> Ekser.Job.is_job(element) end)
    read(input, output, jobs)
  end

  defp read(input, output, jobs) do
    read_input =
      IO.gets(input, "")
      |> String.trim()
      |> String.split()

    retrieved_command = Ekser.Command.resolve_command(read_input, jobs, output)

    new_jobs =
      case retrieved_command do
        {:ok, command, arguments} ->
          Ekser.Command.execute(command, arguments)
          |> execute_chain(input, output, jobs)

        {:error, message} ->
          IO.puts(output, message)
          jobs
      end

    read(input, output, new_jobs)
  end

  defp execute_chain(return, input, output, jobs) do
    case return do
      {message, _} when is_binary(message) -> IO.puts(output, message)
      message when is_binary(message) -> IO.puts(output, message)
      _ -> :ok
    end

    case return do
      {job, new_function} when Ekser.Job.is_job(job) and is_function(new_function) ->
        new_function.(job, is_unique(jobs, job))
        |> execute_chain(input, output, jobs)

      {_, new_function} when is_function(new_function) ->
        IO.gets(input, "")
        |> String.trim()
        |> new_function.()
        |> execute_chain(input, output, jobs)

      _ ->
        jobs
    end
  end

  defp is_unique(jobs, job) when Ekser.Job.is_job(job) do
    duplicate = Ekser.Job.find_job(jobs, job.name)

    case duplicate do
      nil -> true
      _ -> false
    end
  end
end
