defmodule Inkfish.LocalTime do
  def now() do
    :calendar.local_time()
    |> NaiveDateTime.from_erl!()
  end

  def today() do
    now()
    |> NaiveDateTime.to_date()
  end

  def in_hours(nn) do
    seconds_per_hour = 60 * 60

    now()
    |> NaiveDateTime.add(nn * seconds_per_hour)
  end

  def in_days(nn) do
    seconds_per_day = 24 * 60 * 60

    now()
    |> NaiveDateTime.add(nn * seconds_per_day)
  end

  def from_naive!(%NaiveDateTime{} = stamp) do
    case DateTime.from_naive(stamp, timezone()) do
      {:ok, ts} -> ts
      {:ambiguous, ts, _} -> ts
      {:gap, ts, _} -> ts
      other -> raise "Unexpected result: #{inspect(other)}"
    end
  end

  def timezone() do
    Application.get_env(:inkfish, :time_zone)
  end

  def force_local_timezone(dt) do
    date = DateTime.to_date(dt)
    time = DateTime.to_time(dt)
    DateTime.new!(date, time, timezone())
  end

  def as_utc(dt) do
    DateTime.shift_zone!(dt, "Etc/UTC")
  end

  def as_local(dt) do
    DateTime.shift_zone!(dt, timezone())
  end
end
