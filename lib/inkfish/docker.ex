defmodule Inkfish.Docker do
  def base do
    "http+unix://%2Fvar%2Frun%2Fdocker.sock/"
  end
  
  def get!(path) do
    resp = Path.join(base(), path)
    |> HTTPoison.get!()

    200 = resp.status_code
    Jason.decode!(resp.body)
  end

  def list_containers() do
    get!("/containers/json")
  end

  def list_images() do
    get!("/images/json")
  end

end
