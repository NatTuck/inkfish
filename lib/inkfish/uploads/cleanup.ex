defmodule Inkfish.Uploads.Cleanup do
  import Ecto.Query, warn: false
  alias Inkfish.Repo

  alias Inkfish.Uploads
  alias Inkfish.Uploads.Upload

  def cleanup() do
    []
    |> Enum.concat(garbage_subs())
    |> Enum.concat(garbage_user_photos())
    |> Enum.concat(garbage_assignment_starters())
    |> Enum.concat(garbage_assignment_solutions())
    |> Enum.each(&Uploads.delete_upload/1)
  end

  def garbage_subs() do
    Repo.all(
      from up in Upload,
        left_join: subs in assoc(up, :subs),
        preload: [subs: subs],
        where: up.kind == "sub",
        where: is_nil(subs.id),
        where: up.inserted_at < fragment("now()::timestamp - interval '2 days'")
    )
  end

  def garbage_user_photos() do
    Repo.all(
      from up in Upload,
        left_join: photo_user in assoc(up, :photo_user),
        preload: [photo_user: photo_user],
        where: up.kind == "user_photo",
        where: is_nil(photo_user.id),
        where: up.inserted_at < fragment("now()::timestamp - interval '2 days'")
    )
  end

  def garbage_assignment_starters() do
    Repo.all(
      from up in Upload,
        left_join: as in assoc(up, :starter_assignment),
        preload: [starter_assignment: as],
        where: up.kind == "assignment_starter",
        where: is_nil(as.id),
        where: up.inserted_at < fragment("now()::timestamp - interval '2 days'")
    )
  end

  def garbage_assignment_solutions() do
    Repo.all(
      from up in Upload,
        left_join: as in assoc(up, :solution_assignment),
        preload: [solution_assignment: as],
        where: up.kind == "assignment_solution",
        where: is_nil(as.id),
        where: up.inserted_at < fragment("now()::timestamp - interval '2 days'")
    )
  end

  def garbage_subs(user_id) do
    Repo.all(
      from up in Upload,
        left_join: subs in assoc(up, :subs),
        preload: [subs: subs],
        where: up.kind == "sub",
        where: up.user_id == ^user_id,
        where: is_nil(subs.id),
        order_by: [desc: up.inserted_at],
        offset: 5
    )
  end

  def garbage_user_photos(user_id) do
    Repo.all(
      from up in Upload,
        left_join: photo_user in assoc(up, :photo_user),
        preload: [photo_user: photo_user],
        where: up.kind == "user_photo",
        where: up.user_id == ^user_id,
        where: is_nil(photo_user.id),
        order_by: [desc: up.inserted_at],
        offset: 5
    )
  end

  def garbage_assignment_starters(user_id) do
    Repo.all(
      from up in Upload,
        left_join: as in assoc(up, :starter_assignment),
        preload: [starter_assignment: as],
        where: up.kind == "assignment_starter",
        where: up.user_id == ^user_id,
        where: is_nil(as.id),
        order_by: [desc: up.inserted_at],
        offset: 5
    )
  end

  def garbage_assignment_solutions(user_id) do
    Repo.all(
      from up in Upload,
        left_join: as in assoc(up, :solution_assignment),
        preload: [solution_assignment: as],
        where: up.kind == "assignment_solution",
        where: up.user_id == ^user_id,
        where: is_nil(as.id),
        order_by: [desc: up.inserted_at],
        offset: 5
    )
  end

  def cleanup_user_uploads(user_id, kind) do
    uploads = case kind do
      "sub" -> garbage_subs(user_id)
      "user_photo" -> garbage_user_photos(user_id)
      "assignment_starter" -> garbage_assignment_starters(user_id)
      "assignment_solution" -> garbage_assignment_solutions(user_id)
      _ -> []
    end

    Enum.each(uploads, &Uploads.delete_upload/1)
  end
end
