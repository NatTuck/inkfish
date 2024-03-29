defmodule InkfishWeb.Admin.UploadController do
  use InkfishWeb, :controller

  alias Inkfish.Uploads

  def index(conn, _params) do
    uploads = Uploads.list_uploads()
    render(conn, "index.html", uploads: uploads)
  end
end
