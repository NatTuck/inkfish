defmodule Inkfish.LocalTime do
  def now() do
    {:ok, now} = :calendar.local_time()
    |> NaiveDateTime.from_erl()
    from_naive!(now)
  end

  def today() do
    now()
    |> DateTime.to_date()
  end

  def in_days(nn) do
    seconds_per_day = 24 * 60 * 60
    now()
    |> DateTime.add(nn * seconds_per_day)
  end

  def from_naive!(%NaiveDateTime{} = stamp) do
    tz = Application.get_env(:inkfish, :time_zone)
    case DateTime.from_naive(stamp, tz) do
      {:ok, ts} -> ts
      {:ambiguous, ts, _} -> ts
      {:gap, ts, _} -> ts
      other -> raise "Unexpected result: #{inspect(other)}"
    end
  end
end
