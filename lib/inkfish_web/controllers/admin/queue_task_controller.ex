defmodule InkfishWeb.Admin.AutobotController do
  use InkfishWeb, :controller1

  def index(conn, _params) do
    tasks = Inkfish.Autobots.list()
    render(conn, :index)
  end
end
