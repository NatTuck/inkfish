defmodule AddAdminUser do
  alias Inkfish.Users
  alias InkfishWeb.ViewHelpers

  def main() do
    fields = %{
	email: "nt1171@usnh.edu",
	password: "jebee4Zi5Hee",
	password_confirmation: "jebee4Zi5Hee",
	given_name: "Nat",
	surname: "Tuck",
	is_admin: true
    }
    {:ok, user} = Users.create_user(fields)
    ViewHelpers.user_display_name(user)
  end
end

AddAdminUser.main()
