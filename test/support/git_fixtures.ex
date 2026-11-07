defmodule Inkfish.GitFixtures do
  alias Inkfish.Sandbox.TempFs
  alias Inkfish.Uploads.Git

  @clone_script Path.join(
                  :code.priv_dir(:inkfish),
                  "scripts/upload_git_clone.sh"
                )

  def clone_script, do: @clone_script

  def make_repo(base, name, setup \\ fn _ -> :ok end) do
    src = Path.join(base, name)
    File.mkdir_p!(src)
    git!(["init", "-q"], cd: src)
    git!(["config", "user.email", "test@example.com"], cd: src)
    git!(["config", "user.name", "Test"], cd: src)
    setup.(src)
    git!(["add", "-A"], cd: src)
    git!(["commit", "-qm", "init"], cd: src)

    bare = Path.join(base, "#{name}.git")
    git!(["clone", "-q", "--bare", src, bare])

    # Serve partial-clone filters. Without this the local transport answers
    # `--filter` with "filtering not recognized by server, ignoring", and the
    # blob the fetch was told to skip is downloaded anyway -- so the filter
    # would never actually be exercised by a test.
    git!(["config", "uploadpack.allowFilter", "true"], cd: bare)

    bare
  end

  # A bare repository with more than one branch, so the default-branch question
  # is actually decided by the script rather than by there being only one
  # answer. `branch` is created from `branch_setup` and left as a second branch;
  # HEAD in the bare repository stays on the default branch the clone inherited.
  def make_repo_with_branch(base, name, branch, main_setup, branch_setup) do
    bare = make_repo(base, name, main_setup)

    work = Path.join(base, "#{name}-work")
    git!(["clone", "-q", bare, work])
    git!(["config", "user.email", "test@example.com"], cd: work)
    git!(["config", "user.name", "Test"], cd: work)
    git!(["checkout", "-q", "-b", branch], cd: work)
    branch_setup.(work)
    git!(["add", "-A"], cd: work)
    git!(["commit", "-qm", branch], cd: work)
    git!(["push", "-q", "origin", branch], cd: work)

    bare
  end

  # Run the clone script exactly the way production does: `Git.start_clone/1`
  # builds these same two mounts through `Inkfish.Sandbox.TempFs` -- the
  # temporary checkout budget and the saved budget (plus a page per allowed
  # file, which `Git.clone_mounts/2` computes) -- and hands them to Ittys. Only
  # the runner differs here, because a test wants the output and exit status
  # back.
  def run_clone_script(repo, opts \\ []) do
    submit_size = Keyword.get(opts, :submit_size, "5m")
    max_files = Keyword.get(opts, :max_files, 2000)

    {:ok, [unshare | args]} =
      TempFs.unshare_argv(
        Git.clone_mounts(submit_size, max_files),
        "bash",
        [@clone_script]
      )

    System.cmd(unshare, args,
      env: clone_env(repo, submit_size, max_files, opts),
      stderr_to_stdout: true
    )
  end

  def clone_env(repo, submit_size, max_files, opts) do
    [
      {"REPO", repo},
      {"CLONE_SIZE", "100m"},
      {"SUBMIT_SIZE", submit_size},
      {"MAX_FILES", to_string(max_files)},
      {"BLOB_LIMIT", Keyword.get(opts, :blob_limit, submit_size)},
      {"GIT_IGNORE", Keyword.get_lazy(opts, :ignore, &ignore_list/0)},
      {"GIT_ALLOW_PROTOCOL",
       Keyword.get(opts, :protocols, "https:http:git:file")},
      {"COOKIE", "testcookie"}
    ]
  end

  def ignore_list do
    :inkfish
    |> Application.get_env(:git_ignore, [])
    |> Enum.join(" ")
  end

  def git!(args, opts \\ []) do
    {out, 0} = System.cmd("git", args, opts)
    String.trim(out)
  end
end
