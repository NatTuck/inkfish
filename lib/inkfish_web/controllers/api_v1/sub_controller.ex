defmodule InkfishWeb.ApiV1.SubController do
  use InkfishWeb, :controller1

  alias Inkfish.Subs
  alias Inkfish.Subs.Sub
  alias Inkfish.Assignments
  alias Inkfish.Users
  alias Inkfish.Uploads
  alias Inkfish.Teams
  alias Inkfish.Repo

  action_fallback InkfishWeb.FallbackController

  plug InkfishWeb.Plugs.RequireApiUser

  # There are intentinally no update or delete functions
  # here; do not add them.

  def index(conn, params) do
    case Map.fetch(params, "assignment_id") do
      {:ok, asg_id_param} when is_binary(asg_id_param) and asg_id_param != "" ->
        # Convert to integer for lookup. This might raise ArgumentError.
        asg_id = String.to_integer(asg_id_param)

        user = conn.assigns[:current_user]

        # Fetch the assignment to get its course_id. This might raise Ecto.NoResultsError.
        assignment = Assignments.get_assignment_path!(asg_id)
        course_id = assignment.bucket.course_id

        # Find the user's registration for this course
        user_reg = Users.get_reg_by_user_and_course(user.id, course_id)

        # Determine reg_id to filter by
        reg_id_filter =
          if Map.get(params, "all") && user_reg &&
               (user_reg.is_staff || user_reg.is_prof) do
            # Staff/prof with 'all' param sees all subs for the assignment
            nil
          else
            # Otherwise, filter by current user's reg_id (if they have one for this course)
            user_reg && user_reg.id
          end

        # Handle pagination
        # Default to "0" string, then convert
        page = Map.get(params, "page", "0") |> String.to_integer()

        # Call Subs.list_subs_for_api
        subs = Subs.list_subs_for_api(asg_id, reg_id_filter, page)

        conn
        # Use put_view
        |> put_view(InkfishWeb.ApiV1.SubJSON)
        # Use render/2
        |> render(:index, subs: subs)

      # assignment_id is missing, empty string, or not a binary
      _ ->
        conn
        |> put_status(:bad_request)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:error,
          message: "assignment_id is required and must be a non-empty string"
        )
    end
  end

  def create(conn, params) do
    user = conn.assigns[:current_user]

    with {:ok, reg_id} <- parse_and_validate_id(params, "reg_id"),
         {:ok, assignment_id} <- parse_and_validate_id(params, "assignment_id"),
         {:ok, hours_spent} <- parse_and_validate_decimal(params, "hours_spent"),
         {:ok, file_name} <- Map.fetch(params, "file_name"),
         {:ok, file_contents} <- Map.fetch(params, "file_contents"),
         {:ok, reg} <- validate_reg_ownership(reg_id, user),
         {:ok, assignment} <- validate_assignment_exists(assignment_id) do
      # Create a temporary file for the upload
      temp_file_path = Path.join(System.tmp_dir!(), "api_upload_#{System.unique_integer()}")
      File.write!(temp_file_path, file_contents)

      multi =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:upload, fn _repo, _changes ->
          upload_attrs = %{
            name: file_name,
            kind: "sub_upload", # Assuming a kind for submission uploads
            user_id: user.id,
            upload: %{path: temp_file_path, filename: file_name}
          }
          Uploads.create_upload(upload_attrs)
        end)
        |> Ecto.Multi.insert(:sub, fn %{upload: upload} ->
          # Need to get the team for the reg and assignment
          team = Teams.get_active_team(assignment, reg)
          if team do
            sub_attrs = %{
              assignment_id: assignment.id,
              reg_id: reg.id,
              team_id: team.id,
              upload_id: upload.id,
              hours_spent: hours_spent,
              note: Map.get(params, "note", "") # Optional note
            }
            Sub.changeset(%Sub{}, sub_attrs)
          else
            # If no active team, return an error
            {:error, "No active team found for this registration and assignment."}
          end
        end)

      case Repo.transaction(multi) do
        {:ok, %{sub: sub}} ->
          # Clean up temporary file
          File.rm(temp_file_path)
          conn
          |> put_status(:created)
          |> put_resp_header("location", ~p"/api/v1/subs/#{sub}")
          |> put_view(InkfishWeb.ApiV1.SubJSON)
          |> render(:show, sub: sub)

        {:error, _name, changeset_or_error, _changes} ->
          File.rm(temp_file_path) # Clean up temporary file on error
          # Handle specific errors from multi
          case changeset_or_error do
            %Ecto.Changeset{} = changeset ->
              conn
              |> put_status(:unprocessable_entity)
              |> put_view(InkfishWeb.ChangesetJSON)
              |> render(:error, changeset: changeset)
            message when is_binary(message) ->
              conn
              |> put_status(:bad_request)
              |> put_view(InkfishWeb.ErrorJSON)
              |> render(:error, message: message)
            _ ->
              conn
              |> put_status(:internal_server_error)
              |> put_view(InkfishWeb.ErrorJSON)
              |> render(:error, message: "An unexpected error occurred.")
          end
      end
    else
      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> put_view(InkfishWeb.ErrorJSON)
        |> render(:error, message: message)
    end
  end

  def show(conn, %{"id" => id_str}) do
    user = conn.assigns[:current_user]
    # Convert ID to integer. This might raise ArgumentError.
    id = String.to_integer(id_str)

    # This might raise Ecto.NoResultsError.
    sub = Subs.get_sub!(id)

    # Check if the current user is the submitter of this sub
    is_submitter = sub.reg.user_id == user.id

    # Check if the current user is staff/prof in the sub's course
    course_id = sub.assignment.bucket.course_id
    user_reg_in_course = Users.get_reg_by_user_and_course(user.id, course_id)

    is_staff_or_prof =
      user_reg_in_course &&
        (user_reg_in_course.is_staff || user_reg_in_course.is_prof)

    if is_submitter || is_staff_or_prof do
      conn
      # Use put_view
      |> put_view(InkfishWeb.ApiV1.SubJSON)
      # Use render/2
      |> render(:show, sub: sub)
    else
      # Deny access: return 404 Not Found to avoid leaking information about existing IDs
      conn
      |> put_status(:not_found)
      # Use put_view
      |> put_view(InkfishWeb.ErrorJSON)
      # Use render/2
      |> render(:not_found)
    end
  end

  # Helper functions for parsing and validation
  defp parse_and_validate_id(params, key) do
    case Map.fetch(params, key) do
      {:ok, id_str} when is_binary(id_str) and id_str != "" ->
        try do
          {:ok, String.to_integer(id_str)}
        rescue
          ArgumentError -> {:error, "#{key} must be a valid integer"}
        end
      _ -> {:error, "#{key} is required and must be a non-empty string"}
    end
  end

  defp parse_and_validate_decimal(params, key) do
    case Map.fetch(params, key) do
      {:ok, val_str} when is_binary(val_str) and val_str != "" ->
        try do
          {:ok, Decimal.new(val_str)}
        rescue
          ArgumentError -> {:error, "#{key} must be a valid decimal number"}
        end
      _ -> {:error, "#{key} is required and must be a non-empty string"}
    end
  end

  defp validate_reg_ownership(reg_id, user) do
    case Users.get_reg(reg_id) do
      %Users.Reg{user_id: ^(user.id)} = reg -> {:ok, reg}
      _ -> {:error, "Registration not found or does not belong to current user."}
    end
  end

  defp validate_assignment_exists(assignment_id) do
    case Assignments.get_assignment(assignment_id) do
      %Assignments.Assignment{} = assignment -> {:ok, assignment}
      _ -> {:error, "Assignment not found."}
    end
  end
end
