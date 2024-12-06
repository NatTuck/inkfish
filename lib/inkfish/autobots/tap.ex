defmodule Inkfish.Autobots.Tap do
  @doc """
  Parses TAP as output by Perl's Test::Simple or Python's tappy.

  Returns {:ok, {passed, count}} on success.

  If it gets confused, returns {:ok, {0, 1}}.
  """
  def score(text) do
    try do
      score!(text)
    rescue
      _err ->
        # IO.inspect({__MODULE__, _err})
        {:ok, {0, 1}}
    end
  end

  @doc """
  Parses TAP as output by Perl's Test::Simple.

  Returns {:ok, {passed, count}} on success.

  Crashes on failure.
  """
  def score!(text) do
    lines = String.split(text, "\n")

    [count_dec] = Enum.filter(lines, &(&1 =~ ~r/^\d+\.\.\d+$/))

    [_, "1", total] = Regex.run(~r/^(\d+)\.\.(\d+)$/, count_dec)
    {total, _} = Integer.parse(total)

    test_lines =
      Enum.filter(lines, fn line ->
        line =~ ~r/^ok/ || line =~ ~r/^not/
      end)

    tests =
      Enum.map(test_lines, fn line ->
        pat = ~r/^(ok|not ok)\s+(\d+)\s+(?:-\s+)?(.*)$/
        [_, ok, num, _text] = Regex.run(pat, line)
        {num, _} = Integer.parse(num)
        {num, ok == "ok"}
      end)
      |> Enum.into(%{})

    passed =
      Enum.reduce(1..total, 0, fn ii, acc ->
        if tests[ii] do
          acc + 1
        else
          acc
        end
      end)

    {:ok, {passed, total}}
  end
end
