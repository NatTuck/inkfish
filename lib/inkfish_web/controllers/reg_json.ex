defmodule InkfishWeb.RegJSON do
  use InkfishWeb, :json

  alias Inkfish.Users.Reg
  alias InkfishWeb.UserJSON

  def index(%{regs: regs}) do
    %{data: for(reg <- regs, do: data(reg))}
  end

  def show(%{reg: nil}), do: %{data: nil}

  def show(%{reg: reg}) do
    %{data: data(reg)}
  end

  def data(nil), do: nil

  def data(%Reg{} = reg) do
    user = get_assoc(reg, :user)

    %{
      id: reg.id,
      is_student: reg.is_student,
      user: UserJSON.data(user)
    }
  end
end
