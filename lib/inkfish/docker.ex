defmodule Inkfish.Docker do
  use OK.Pipe
  
  def base do
    "http+unix://%2Fvar%2Frun%2Fdocker.sock/"
  end

  def get_200_body(resp) do
    if resp.status_code == 200 do
      {:ok, resp.body}
    else
      {:error, "HTTP #{resp.status_code}"}
    end
  end

  def get(path) do
    uri = Path.join(base(), path)
    {:ok, uri}
    ~>> HTTPoison.get()
    ~>> get_200_body()
    ~>> Jason.decode()
  end

  def list_containers() do
    get("/containers/json")
  end

  def list_images() do
    get("/images/json")
  end

  def get_image_by_tag(tag) do
    list_images()
    ~>> Enum.find(&(Enum.member?(&1["RepoTags"], tag)))
  end
end
