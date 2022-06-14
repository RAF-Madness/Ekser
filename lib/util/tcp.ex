defmodule Ekser.TCP do
  defguardp is_byte(term) when is_integer(term) and term >= 0 and term <= 255

  defguardp is_short(term) when is_integer(term) and term >= 0 and term <= 65535

  defguardp is_ipv4_fragment(term, pos) when is_byte(elem(term, pos))

  defguardp is_ipv6_fragment(term, pos) when is_short(elem(term, pos))

  defguardp is_ipv4(term)
            when is_tuple(term) and tuple_size(term) == 4 and is_ipv4_fragment(term, 0) and
                   is_ipv4_fragment(term, 1) and is_ipv4_fragment(term, 2) and
                   is_ipv4_fragment(term, 3)

  defguardp is_ipv6(term)
            when is_tuple(term) and tuple_size(term) == 8 and is_ipv6_fragment(term, 0) and
                   is_ipv6_fragment(term, 1) and is_ipv6_fragment(term, 2) and
                   is_ipv6_fragment(term, 3) and is_ipv6_fragment(term, 4) and
                   is_ipv6_fragment(term, 5) and is_ipv6_fragment(term, 6) and
                   is_ipv6_fragment(term, 7)

  defguard is_tcp_ip(term) when is_ipv4(term) or is_ipv6(term)

  defguard is_tcp_port(term) when is_integer(term) and term >= 1024 and term <= 65535

  @spec port_prompt() :: String.t()
  def port_prompt() do
    "Port must be a valid port number, an integer between 1024 and 65535 (inclusive)."
  end

  @spec to_ip(String.t()) :: tuple() | :error
  def to_ip(ip_string) do
    with true <- is_binary(ip_string),
         fragments <- String.split(ip_string, "."),
         parsed <- Enum.map(fragments, &Integer.parse(&1)),
         true <-
           Enum.all?(parsed, fn element -> is_tuple(element) and tuple_size(element) === 2 end),
         parse_results <- Enum.map(parsed, &elem(&1, 0)),
         ip <- List.to_tuple(parse_results),
         true <- is_tcp_ip(ip) do
      ip
    else
      _ -> :error
    end
  end

  @spec from_ip(tuple()) :: String.t()
  def from_ip(ip) do
    case is_tuple(ip) do
      true ->
        ip
        |> Tuple.to_list()
        |> Enum.join(".")

      false ->
        :error
    end
  end

  @spec socket_options() :: list()
  def socket_options() do
    [:binary, packet: 0, active: false, reuseaddr: true]
  end

  @spec send(String.t(), tuple(), pos_integer()) :: :ok
  def send(message, ip, port) do
    {:ok, socket} = :gen_tcp.connect(ip, port, socket_options())

    :gen_tcp.send(socket, message)

    :gen_tcp.close(socket)
  end
end
