defmodule Inkfish.UsersTest do
  use Inkfish.DataCase
  import Inkfish.Factory

  alias Inkfish.Users

  describe "users" do
    alias Inkfish.Users.User

    test "list_users/0 returns users" do
      user = insert(:user)
      users = Users.list_users()
      assert [%User{} | _] = users
      assert Enum.member?(Enum.map(users, & &1.id), user.id)
    end

    test "get_user!/1 returns the user with given id" do
      user = %User{insert(:user) | password: nil, password_confirmation: nil}
      assert drop_assocs(Users.get_user!(user.id)) == drop_assocs(user)
    end

    test "create_user/1 with valid data creates a user" do
      attrs = params_for(:user)
      assert {:ok, %User{} = user} = Users.create_user(attrs)
      assert user.email =~ ~r[sam\d+@example.com]
      assert user.is_admin == false
    end

    test "create_user/1 with invalid data returns error changeset" do
      bad_attrs = %{}
      assert {:error, %Ecto.Changeset{}} = Users.create_user(bad_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = insert(:user)
      attrs = %{nickname: "Steve"}
      assert {:ok, %User{} = user} = Users.update_user(user, attrs)
      assert user.nickname == "Steve"
      assert user.surname == "Smith"
      assert user.is_admin == false
    end

    test "delete_user/1 deletes the user" do
      user = insert(:user)
      assert {:ok, %User{}} = Users.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Users.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = insert(:user)
      assert %Ecto.Changeset{} = Users.change_user(user)
    end
  end

  describe "regs" do
    alias Inkfish.Users.Reg

    test "list_regs/0 returns newly inserted reg" do
      reg = insert(:reg)
      regs = Users.list_regs()
      assert Enum.member?(Enum.map(regs, & &1.id), reg.id)
    end

    test "get_reg!/1 returns the reg with given id" do
      reg = insert(:reg)
      assert drop_assocs(Users.get_reg!(reg.id)) == drop_assocs(reg)
    end

    test "create_reg/1 with valid data creates a reg" do
      params =
        params_for(:reg)
        |> Map.put(:course_id, insert(:course).id)
        |> Map.put(:user_id, insert(:user).id)

      assert {:ok, %Reg{} = reg} = Users.create_reg(params)
      assert reg.is_grader == false
      assert reg.is_prof == false
      assert reg.is_staff == false
      assert reg.is_student == true
    end

    test "create_reg/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_reg(%{})
    end

    test "update_reg/2 with valid data updates the reg" do
      reg = insert(:reg)
      assert {:ok, %Reg{} = reg} = Users.update_reg(reg, %{is_student: true})
      assert reg.is_grader == false
      assert reg.is_prof == false
      assert reg.is_staff == false
      assert reg.is_student == true
    end

    test "update_reg/2 with invalid data returns error changeset" do
      reg = insert(:reg)
      params = %{is_student: true, is_prof: true}
      assert {:error, %Ecto.Changeset{}} = Users.update_reg(reg, params)
      assert drop_assocs(reg) == drop_assocs(Users.get_reg!(reg.id))
    end

    test "delete_reg/1 deletes the reg" do
      reg = insert(:reg)
      assert {:ok, %Reg{}} = Users.delete_reg(reg)
      assert_raise Ecto.NoResultsError, fn -> Users.get_reg!(reg.id) end
    end

    test "change_reg/1 returns a reg changeset" do
      reg = insert(:reg)
      assert %Ecto.Changeset{} = Users.change_reg(reg)
    end
  end

  alias Inkfish.Users.User

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Users.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Users.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Users.get_user_by_email_and_password(
               "unknown@example.com",
               "hello world!"
             )
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Users.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Users.get_user_by_email_and_password(user.email, user.password)
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Users.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Users.get_user!(user.id)
    end
  end

  describe "create_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Users.create_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["Email domain must be 'example.com'.", "can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} =
        Users.create_user(%{email: "not valid", password: "not valid"})

      assert %{
               email: [
                 "Email domain must be 'example.com'.",
                 "has invalid format"
               ],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Users.create_user(%{email: too_long, password: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Users.create_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Users.create_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = Users.create_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert !is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Users.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Users.change_user_password(%User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert !is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Users.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Users.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Users.update_user_password(user, %{password: "new valid password"})

      # assert is_nil(user.password)
      assert Users.get_user_by_email_and_password(
               user.email,
               "new valid password"
             )
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    params_for(:user, attrs)
  end

  def user_fixture(attrs \\ %{}) do
    attrs = valid_user_attributes(attrs)
    {:ok, user} = Inkfish.Users.create_user(attrs)
    %User{user | password: attrs[:password]}
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
