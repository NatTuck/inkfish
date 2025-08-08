defmodule Inkfish.Meetings do
  @moduledoc """
  The Meetings context.
  """

  import Ecto.Query, warn: false
  alias Inkfish.Repo

  alias Inkfish.Meetings.Meeting
  alias Inkfish.Courses.Course
  alias Inkfish.Attendances.Attendance

  @doc """
  Returns the list of meetings.

  ## Examples

      iex> list_meetings()
      [%Meeting{}, ...]

  """
  def list_meetings(%Course{} = course) do
    Repo.all(
      from mm in Meeting,
        where: mm.course_id == ^course.id,
        order_by: {:desc, mm.started_at}
    )
    |> Inkfish.Repo.Info.with_local_time()
  end

  @doc """
  Gets a single meeting.

  Raises `Ecto.NoResultsError` if the Meeting does not exist.

  ## Examples

      iex> get_meeting!(123)
      %Meeting{}

      iex> get_meeting!(456)
      ** (Ecto.NoResultsError)

  """
  def get_meeting!(id), do: Repo.get!(Meeting, id)

  def get_latest_meeting(%Course{} = course) do
    Repo.one(
      from mm in Meeting,
        where: mm.course_id == ^course.id,
        order_by: {:desc, mm.started_at},
        limit: 1
    )
  end

  def get_current_meeting(%Course{} = course) do
    if mm = get_latest_meeting(course) do
      now = LocalTime.now()
      diff = abs(DateTime.diff(mm.started_at, now, :minute))

      if diff <= 60 do
        Repo.Info.with_local_time(mm)
      else
        nil
      end
    else
      nil
    end
  end

  def preload_attendances(nil), do: nil

  def preload_attendances(%Meeting{} = mm) do
    mm = Repo.preload(mm, attendances: [reg: [:user]])

    ats =
      for at <- mm.attendances do
        %Attendance{at | meeting: mm}
      end

    %Meeting{mm | attendances: ats}
  end

  @doc """
  Creates a meeting.

  ## Examples

      iex> create_meeting(%{field: value})
      {:ok, %Meeting{}}

      iex> create_meeting(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_meeting(attrs \\ %{}) do
    %Meeting{}
    |> Meeting.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a meeting.

  ## Examples

      iex> update_meeting(meeting, %{field: new_value})
      {:ok, %Meeting{}}

      iex> update_meeting(meeting, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_meeting(%Meeting{} = meeting, attrs) do
    meeting
    |> Meeting.changeset(attrs)
    |> Repo.update()
    |> Repo.Cache.updated()
  end

  @doc """
  Deletes a meeting.

  ## Examples

      iex> delete_meeting(meeting)
      {:ok, %Meeting{}}

      iex> delete_meeting(meeting)
      {:error, %Ecto.Changeset{}}

  """
  def delete_meeting(%Meeting{} = meeting) do
    Repo.delete(meeting)
    |> Repo.Cache.updated()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking meeting changes.

  ## Examples

      iex> change_meeting(meeting)
      %Ecto.Changeset{data: %Meeting{}}

  """
  def change_meeting(%Meeting{} = meeting, attrs \\ %{}) do
    Meeting.changeset(meeting, attrs)
  end
end
