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

    if conf.unpacked_sub do
      tar_up!(Path.join(work, "sub.tar.gz"), conf.unpacked_sub)
    end

    if conf.unpacked_gra do
      tar_up!(Path.join(work, "gra.tar.gz"), conf.unpacked_gra)
    end

    scr = conf.script_dir || raise "No script dir"
    File.cp!(Path.join(scr, "unpack.pl"), Path.join(work, "unpack.pl"))
    File.cp!(Path.join(scr, "simple-driver.pl"), Path.join(work, "driver.pl"))

    gid = conf.ag_job_id || raise "No job id"
    tag = "sandbox:#{gid}"

    cleanup = Path.join(scr, "cleanup-sandboxes.pl")

    cmd = """
      (cd "#{work}" && \
        perl "#{cleanup}" && \
        DOCKER_BUILDKIT=1 docker build -t "#{tag}" .)
    """

    {:ok, %AgImage{tag: tag, cmd: cmd}}
  end

  def dockerfile(conf) do
    """
    FROM #{conf[:base_image] || "inkfish:latest"}

    LABEL inkfish.sandbox=true

    COPY unpack.pl /usr/local/bin
    RUN chmod a+x /usr/local/bin/unpack.pl

    COPY *.pl /var/tmp
    COPY *.gz /var/tmp

    WORKDIR /home/student

    ENV COOKIE=#{conf["COOKIE"]}
    CMD ["perl", "/var/tmp/driver.pl"]
    """
  end
end
