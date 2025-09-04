

defmodule AddUser do
  alias Inkfish.Users
  alias InkfishWeb.ViewHelpers

  def main() do
    if false do
    fields = %{
	email: "job123@usnh.edu",
	password: "jebee4Zi5Hqf",
	password_confirmation: "jebee4Zi5Hqf",
	given_name: "Joe",
	surname: "O'Brian",
	is_admin: false
    }
    {:ok, user} = Users.create_user(fields)
    ViewHelpers.user_display_name(user)
    end 
  end
end

AddUser.main()
