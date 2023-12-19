defmodule Inkfish.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [autogenerate: {Inkfish.LocalTime, :now, []}]

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_confirmation, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :given_name, :string
    field :surname, :string
    field :nickname, :string, default: ""
    field :is_admin, :boolean, default: false
    field :secret, :string


    belongs_to :photo_upload, Inkfish.Uploads.Upload, type: :binary_id
    has_many :regs, Inkfish.Users.Reg

    timestamps()
  end

  def create_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :given_name, :surname])
    |> validate_required([:email, :password, :given_name, :surname])
    |> validate_confirmation(:password)
    |> validate_email()
    |> set_email_confirmed()
    |> validate_password()
  end

  @doc false
  def admin_edit_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :given_name, :surname, :nickname,
                    :photo_upload_id, :is_admin])
    |> validate_required([:email, :given_name, :surname])
    |> validate_email()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :given_name, :surname, :nickname, :photo_upload_id])
    |> validate_required([:email, :given_name, :surname])
    |> validate_email()
  end

  def normalize_email(text) do
    text
    |> String.downcase()
    |> String.trim()
  end

  def validate_email(cset) do
    cset
    |> unique_constraint(:email)
    |> validate_format(:email, ~r/^\S+@\S+\.\S+$/)
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Inkfish.Repo)
  end

  def secret_changeset(user) do
    secret = :crypto.strong_rand_bytes(16) |> Base.encode16
    cast(user, %{secret: secret}, [:secret])
  end

  def validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> hash_password()
  end

  def hash_password(changeset) do
    password = get_change(changeset, :password)
    if password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Argon2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password()
  end

  def set_email_confirmed(cset) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    put_change(cset, :confirmed_at, now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Argon2.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Inkfish.Users.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Argon2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Argon2.no_user_verify()
    false
  end

  def extract_email(text) do
    case Regex.run(~r/\[(\S+@\S+)\]/, text) do
      xs when is_list(xs) and length(xs) > 1 ->
        Enum.at(xs, 1)
      _other ->
        text
    end
  end
end
