defmodule Inkfish.Docker do
  use OK.Pipe
  
  def base do
    "http+unix://%2Fvar%2Frun%2Fdocker.sock/"
  end

  def get_2xx_body(resp) do
    if resp.status_code >= 200 && resp.status_code < 300 do
      {:ok, resp.body}
    else
      {:error, "HTTP #{resp.status_code}"}
    end
  end

  def get(path) do
    uri = Path.join(base(), path)
    {:ok, uri}
    ~>> HTTPoison.get()
    ~>> get_2xx_body()
    ~>> Jason.decode()
  end

  def post_json(url, data) do
    text = Jason.encode!(data)
    hdrs = [{"content-type", "application/json"}]
    HTTPoison.post(url, text, hdrs)
  end

  def post(path, data) do
    uri = Path.join(base(), path)
    {:ok, uri}
    ~>> post_json(data)
    ~>> get_2xx_body()
    ~>> Jason.decode()    
  end

  def list_containers() do
    get("/containers/json")
  end

  def list_all_containers() do
    get("/containers/json?all=true")
  end

  def list_images() do
    get("/images/json")
  end

  def get_image_by_tag(tag) do
    list_images()
    ~>> Enum.find(&(Enum.member?(&1["RepoTags"], tag)))
  end

  def create(image, opts \\ %{}) do
    body = Map.merge(opts, %{Image: image})
    {:ok, %{"Id" => id}} = post("/containers/create", body)
    {:ok, id}
  end

  def default_dockerfile do
    """
    FROM debian:bookworm

    ENV DEBIAN_FRONTEND noninteractive

    RUN apt-get -y update && apt-get -y upgrade

    RUN apt-get install -y locales && \\
        sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && \\
        locale-gen

    RUN apt-get -y install apt-utils adduser

    RUN apt-get -y install debian-goodies util-linux \\
        build-essential perl-doc libipc-run-perl libarchive-zip-perl \\
        wamerican libbsd-dev ruby python3 pkg-config time curl

    RUN adduser student --disabled-password --gecos "Student,,,,"
    """
  end
end
