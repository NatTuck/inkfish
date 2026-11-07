defmodule Inkfish.NoDebugPrintsTest do
  use ExUnit.Case, async: true

  # `IO.puts`/`IO.inspect` in runtime code bypass the logger, so they print in
  # every environment -- including the test suite, whose output is supposed to
  # be silent. Logging is fine (it is leveled, and the tests that provoke a
  # warning capture and assert it). The `mix` tasks are exempt: their output is
  # their interface.
  @exempt_prefixes ~w(lib/mix)

  test "runtime code does not print with IO.puts/IO.inspect" do
    offenders =
      "lib/**/*.ex"
      |> Path.wildcard()
      |> Enum.reject(&exempt?/1)
      |> Enum.flat_map(&offences_in/1)

    assert offenders == []
  end

  defp exempt?(path) do
    Enum.any?(@exempt_prefixes, &String.starts_with?(path, &1))
  end

  defp offences_in(path) do
    {_ast, offences} =
      path
      |> File.read!()
      |> Code.string_to_quoted!()
      |> Macro.prewalk([], fn node, acc -> {node, collect(node, path, acc)} end)

    Enum.reverse(offences)
  end

  defp collect(
         {{:., _, [{:__aliases__, _, [:IO]}, fun]}, meta, _args},
         path,
         acc
       )
       when fun in [:puts, :inspect, :write] do
    [{path, meta[:line], fun} | acc]
  end

  defp collect(_node, _path, acc), do: acc
end
