defmodule Inkfish.Users do
  @moduledoc """
  The Users context.
  """

  import Ecto.Query, warn: false
  alias Inkfish.Repo

  alias Inkfish.Users.{User, UserToken, UserNotifier}

  alias Inkfish.Courses.Course
  alias Inkfish.Users.User

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
    Repo.one! from uu in User,
      where: uu.id == ^id,
      left_join: photo in assoc(uu, :photo_upload),
      preload: [photo_upload: photo]
  end

  def get_an_admin! do
    Repo.one! from uu in User,
      where: uu.is_admin,
      limit: 1
  end

  @doc """
  Gets a single user by id

  Returns nil if User doesn't exist or if given a nil
  user id.
  """
  def get_user(nil), do: nil
  def get_user(id), do: Repo.get(User, id)


  def get_user_by_login!(login) do
    Repo.get_by!(User, login: login)
  end

#  @doc """
#  Authenticate a user by email and password.
#
#  Returns the User on success, or nil on failure.
#  """
#  def auth_and_get_user(login, pass) do
#    case Paddle.authenticate(login, pass) do
#      :ok ->
#        {:ok, data} = Paddle.get(filter: [uid: login])
#        {:ok, user} = create_or_update_from_ldap_data(login, hd(data))
#        user
#      {:error, :invalidCredentials} ->
#        nil
#      {:error, _} ->
#        {:ok, :connected} = Paddle.reconnect()
#        nil
#    end
#  end
#
#  def create_or_update_from_ldap_data(login, data) do
#    attrs = %{
#      login: login,
#      email: hd(data["mail"]),
#      given_name: hd(data["givenName"]),
#      surname: hd(data["sn"]),
#    }
#
#    # FIXME: Overwrites changes to name.
#    %User{}
#    |> User.changeset(attrs)
#    |> Repo.insert(
#      conflict_target: :login,
#      on_conflict: {:replace, [:email, :given_name, :surname]}
#    )
#  end
#
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
    |> User.changeset(attrs)
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
  end

  def add_secret(%User{secret: nil} = user) do
    user
    |> User.secret_changeset()
    |> Repo.update()
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
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  def search_users(query) do
    query = query
    |> String.replace(~r{[%_\\]}, "\\1")
    qq = "%#{query}%"
    Repo.all from uu in User,
      where: ilike(uu.login, ^qq) or ilike(uu.given_name, ^qq) or ilike(uu.surname, ^qq)
  end

  alias Inkfish.Users.Reg

  @doc """
  Returns the list of regs.

  ## Examples

      iex> list_regs()
      [%Reg{}, ...]

  """
  def list_regs do
    Repo.all(Reg)
  end

  alias Inkfish.Courses.Course

  def list_regs_for_course(%Course{} = course),
    do: list_regs_for_course(course.id)

  def list_regs_for_course(course_id) do
    Repo.all from reg in Reg,
      where: reg.course_id == ^course_id,
      inner_join: user in assoc(reg, :user),
      preload: [user: user]
  end

  def list_regs_for_user(%User{} = user) do
    regs = Repo.all from reg in Reg,
      where: reg.user_id == ^user.id,
      inner_join: course in assoc(reg, :course),
      preload: [course: course]

    Enum.map regs, fn reg ->
      %{reg | user: user}
    end
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
    Repo.one! from reg in Reg,
      where: reg.id == ^id,
      inner_join: user in assoc(reg, :user),
      inner_join: course in assoc(reg, :course),
      preload: [user: user, course: course]
  end

  def get_reg(id) do
    try do
      get_reg!(id)
    rescue
      Ecto.NoResultsError -> nil
    end
  end

  def get_reg_path!(id) do
    Repo.one! from reg in Reg,
      where: reg.id == ^id,
      inner_join: course in assoc(reg, :course),
      preload: [course: course]
  end

  def find_reg(%User{} = user, %Course{} = course) do
    reg = Repo.one from reg in Reg,
      where: reg.user_id == ^user.id and reg.course_id == ^course.id

    if user.is_admin && is_nil(reg) do
      # Admins are always registered for every course as no role.
      {:ok, reg} = create_reg(%{user_id: user.id, course_id: course.id})
      reg
    else
      reg
    end
  end

  def preload_reg_teams!(%Reg{} = reg) do
    Repo.preload(reg, [teams: :subs])
  end

  def get_reg_for_grading_tasks!(reg_id) do
    Repo.one from reg in Reg,
      where: reg.id == ^reg_id,
      left_join: subs in assoc(reg, :grading_subs),
      left_join: asg in assoc(subs, :assignment),
      left_join: sreg in assoc(subs, :reg),
      left_join: suser in assoc(sreg, :user),
      preload: [
        gradings_subs: {subs, assignment: asg,
                              reg: {sreg, user: suser}}
      ]
  end

  @doc """
  Creates a reg.

  ## Examples

      iex> create_reg(%{field: value})
      {:ok, %Reg{}}

      iex> create_reg(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_reg(%{"user_login" => user_login} = attrs) do
    login = User.normalize_login(user_login)
    attrs
    |> Map.put("user_id", get_user_by_login!(login).id)
    |> Map.delete("user_login")
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

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
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
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end
end
