defmodule Inkfish.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  alias Inkfish.Repo

  alias Inkfish.Users.User
  alias Inkfish.Users.UserNotifier

  alias Inkfish.Courses.Course
  alias Inkfish.Users.User
  alias Inkfish.Users.Reg

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id) do
    Repo.one!(
      from uu in User,
        where: uu.id == ^id,
        left_join: photo in assoc(uu, :photo_upload),
        preload: [photo_upload: photo]
    )
  end

  def get_an_admin! do
    Repo.one!(
      from uu in User,
        where: uu.is_admin,
        limit: 1
    )
  end

  @doc """
  Gets a single user by id

  Returns nil if User doesn't exist or if given a nil
  user id.
  """
  def get_user(nil), do: nil
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a single user by id

  Returns nil if User doesn't exist or if given a nil
  user id.
  """
  def get_user_by_email!(nil) do
    raise "Nil email"
  end

  def get_user_by_email!(email) do
    Repo.get_by!(User, email: email)
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
    |> Repo.Cache.updated()
  end

  def admin_update_user(%User{} = user, attrs, %User{} = editor) do
    if editor.id == user.id do
      # You can't de-admin yourself.
      user
      |> User.changeset(attrs)
      |> Repo.update()
      |> Repo.Cache.updated()
    else
      user
      |> User.admin_edit_changeset(attrs)
      |> Repo.update()
      |> Repo.Cache.updated()
    end
  end

  def add_secret(%User{secret: nil} = user) do
    user
    |> User.secret_changeset()
    |> Repo.update()
    |> Repo.Cache.updated()
  end

  def add_secret(user), do: {:ok, user}

  @doc """
  Deletes a User.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    try do
      Repo.delete(user)
      |> Repo.Cache.updated()
    rescue
      Ecto.ConstraintError ->
        {:error, "User #{user.email} can't be deleted"}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user() do
    change_user(%User{})
  end

  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  def search_users(query) do
    query =
      query
      |> String.replace(~r{[%_\\]}, "\\1")

    qq = "%#{query}%"

    Repo.all(
      from uu in User,
        where:
          ilike(uu.email, ^qq) or ilike(uu.given_name, ^qq) or
            ilike(uu.surname, ^qq)
    )
  end

  @doc """
  Returns the list of regs.

  ## Examples

      iex> list_regs()
      [%Reg{}, ...]

  """
  def list_regs do
    Repo.all(Reg)
  end

  def list_regs_for_course(%Course{} = course),
    do: list_regs_for_course(course.id)

  def list_regs_for_course(course_id) do
    Repo.all(
      from reg in Reg,
        where: reg.course_id == ^course_id,
        inner_join: user in assoc(reg, :user),
        preload: [user: user]
    )
  end

  def list_regs_for_user(%User{} = user) do
    regs =
      Repo.all(
        from reg in Reg,
          where: reg.user_id == ^user.id,
          inner_join: course in assoc(reg, :course),
          preload: [course: course]
      )

    Enum.map(regs, fn reg ->
      %{reg | user: user}
    end)
  end

  def list_regs_for_user(user_id) do
    user = get_user!(user_id)
    list_regs_for_user(user)
  end

  @doc """
  Gets a single reg.

  Raises `Ecto.NoResultsError` if the Reg does not exist.

  ## Examples

      iex> get_reg!(123)
      %Reg{}

      iex> get_reg!(456)
      ** (Ecto.NoResultsError)

  """
  def get_reg!(id) do
    Repo.one!(
      from reg in Reg,
        where: reg.id == ^id,
        inner_join: user in assoc(reg, :user),
        inner_join: course in assoc(reg, :course),
        preload: [user: user, course: course]
    )
  end

  def get_reg(id) do
    try do
      get_reg!(id)
    rescue
      Ecto.NoResultsError -> nil
    end
  end

  @doc """
  Retrieves a user's registration for a specific course.
  """
  def get_reg_by_user_and_course(user_id, course_id) do
    Repo.one(
      from(r in Reg,
        where: r.user_id == ^user_id and r.course_id == ^course_id
      )
    )
  end

  def find_reg(_user, nil), do: {:error, :no_course}
  def find_reg(nil, _course), do: {:error, :no_user}

  def find_reg(%User{} = user, %Course{} = course) do
    reg = get_reg_by_user_and_course(user.id, course.id)

    if user.is_admin && is_nil(reg) do
      # Admins are always registered for every course as no role.
      {:ok, reg} = create_reg(%{user_id: user.id, course_id: course.id})
      {:ok, %Reg{reg | user: user, course: course}}
    else
      if is_nil(reg) do
        {:error, :no_reg}
      else
        {:ok, %Reg{reg | user: user, course: course}}
      end
    end
  end

  def preload_reg_teams!(%Reg{} = reg) do
    Repo.preload(reg, teams: [:subs, team_members: [reg: :user]])
  end

  def get_reg_for_grading_tasks!(reg_id) do
    Repo.one(
      from reg in Reg,
        where: reg.id == ^reg_id,
        left_join: subs in assoc(reg, :grading_subs),
        left_join: asg in assoc(subs, :assignment),
        left_join: sreg in assoc(subs, :reg),
        left_join: suser in assoc(sreg, :user),
        preload: [
          gradings_subs: {subs, assignment: asg, reg: {sreg, user: suser}}
        ]
    )
  end

  @doc """
  Creates a reg.

  ## Examples

      iex> create_reg(%{field: value})
      {:ok, %Reg{}}

      iex> create_reg(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_reg(%{"user_email" => user_email} = attrs) do
    email =
      user_email
      |> User.extract_email()
      |> User.normalize_email()

    attrs
    |> Map.put("user_id", get_user_by_email!(email).id)
    |> Map.delete("user_email")
    |> create_reg()
  end

  def create_reg(attrs) do
    %Reg{}
    |> Reg.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a reg.

  ## Examples

      iex> update_reg(reg, %{field: new_value})
      {:ok, %Reg{}}

      iex> update_reg(reg, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_reg(%Reg{} = reg, attrs) do
    reg
    |> Reg.changeset(attrs)
    |> Repo.update()
    |> Repo.Cache.updated()
  end

  @doc """
  Deletes a Reg.

  ## Examples

      iex> delete_reg(reg)
      {:ok, %Reg{}}

      iex> delete_reg(reg)
      {:error, %Ecto.Changeset{}}

  """
  def delete_reg(%Reg{} = reg) do
    Repo.delete(reg)
    |> Repo.Cache.updated()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking reg changes.

  ## Examples

      iex> change_reg(reg)
      %Ecto.Changeset{source: %Reg{}}

  """
  def change_reg(%Reg{} = reg) do
    Reg.changeset(reg, %{})
  end

  def next_due(%Reg{} = reg) do
    Inkfish.Assignments.next_due(reg.course_id, reg.user_id)
  end

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  ## Settings

  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Repo.update()
    |> Repo.Cache.updated()
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_reg_email(email, url) do
    if User.domain_allowed?(email) do
      UserNotifier.deliver_reg_email(email, url)
    else
      domain = User.get_reg_email_domain()
      {:error, "Email domain must be '#{domain}'."}
    end
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

    ## Examples

      iex> deliver_user_reset_password_instructions(user, url(~p"/users/reset_password/#{token}"))
        {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_auth_email(%User{} = user, reset_url) do
    UserNotifier.deliver_auth_email(user, reset_url)
  end
end
