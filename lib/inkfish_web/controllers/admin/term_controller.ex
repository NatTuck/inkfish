defmodule InkfishWeb.Admin.TermController do
  use InkfishWeb, :controller1

  def index(conn, _params) do
    render(conn, :index)
  end

  def create(conn, _params) do
    cmd = "echo 1; sleep 2; echo 2; sleep 2; echo 3; sleep 2; echo 4"
    #cmd = "(cd ~/Code/inkfish/notes/docker/default && docker build .)"
    {:ok, uuid} = Inkfish.Itty.run(cmd)
    redirect(conn, to: ~p"/admin/terms/#{uuid}")
  end

  def show(conn, %{"id" => id}) do
    render(conn, :show, id: id)
  end
end
