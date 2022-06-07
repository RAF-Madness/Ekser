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
# ● quit - Uredno gašenje čvora
defmodule Ekser.Commander do
  require Ekser.Command
  require Ekser.Job
  use Task

  def child_spec(filename, jobs) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [filename, jobs]},
      restart: :transient,
      significant: true,
      shutdown: 5000,
      type: :worker
    }
  end

  def start_link(jobs, filename) do
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
      |> clean_and_split()

    with {:ok, command, arguments} <- Ekser.Command.get_command(read_input, jobs),
         {message, job} <- Ekser.Command.execute(input, output, command, arguments) do
      IO.puts(output, message)
      read(input, output, [job | jobs])
    else
      {:error, message} ->
        IO.puts(output, message)
        read(input, output, jobs)

      message ->
        IO.puts(output, message)
        read(input, output, jobs)
    end
  end

  defp clean_and_split(line) do
    String.trim(line)
    |> String.split()
  end
end
