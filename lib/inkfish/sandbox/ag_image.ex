defmodule Inkfish.Sandbox.AgImage do
  defstruct [:tag, :cmd]

  alias __MODULE__

  def tar_up!(tarball, path) do
    {_, 0} =
      System.cmd("bash", [
        "-c",
        ~s{(cd "#{path}" && tar czf "#{tarball}" .)}
      ])
  end

  def prepare(conf) do
    {:ok, work} = Briefly.create(type: :directory)

    Path.join(work, "conf.json")
    |> File.write(Jason.encode!(conf))

    Path.join(work, "Dockerfile")
    |> File.write(dockerfile(conf))

    if conf["SUB"] do
      tar_up!(Path.join(work, "sub.tar.gz"), conf["SUB"])
    end

    if conf["GRA"] do
      tar_up!(Path.join(work, "gra.tar.gz"), conf["GRA"])
    end

    scr = conf["SCR"] || raise "No script dir"
    File.cp!(Path.join(scr, "unpack.pl"), Path.join(work, "unpack.pl"))
    File.cp!(Path.join(scr, "simple-driver.pl"), Path.join(work, "driver.pl"))

    gid = conf["GID"] || raise "No grade id"
    tag = "sandbox:#{gid}"

    cmd = ~s[(cd "#{work}" && DOCKER_BUILDKIT=1 docker build -t "#{tag}" .)]
    {:ok, %AgImage{tag: tag, cmd: cmd}}
  end

  def dockerfile(conf) do
    """
    FROM #{conf["BASE"]}

    LABEL inkfish.sandbox=true

    COPY *.pl /var/tmp

    USER student

    COPY *.gz /var/tmp

    WORKDIR /home/student

    ENV COOKIE=#{conf["COOKIE"]}
    CMD ["perl", "/var/tmp/driver.pl"]
    """
  end
end
