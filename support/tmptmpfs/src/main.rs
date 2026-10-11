//! tmptmpfs - private, size-limited tmpfs mounts without root.
//!
//!     tmptmpfs run [--tmpfs NAME=SIZE]... -- CMD [ARG...]
//!
//! Creates an unprivileged user namespace, maps the caller onto uid/gid 0
//! inside it, enters a private mount namespace, mounts one tmpfs per
//! `--tmpfs` option, exports each `NAME` into the environment pointing at
//! its mount path, and then execs CMD.
//!
//! No setuid bit, no root, no background process, no polling. Every failure
//! prints a diagnostic on stderr and exits non-zero; nothing waits forever.

use std::env;
use std::ffi::{CString, OsString};
use std::fs::{self, OpenOptions};
use std::io::{self, Write};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{self, Command};
use std::ptr;

const USAGE: &str = "\
usage: tmptmpfs run [--tmpfs NAME=SIZE]... -- CMD [ARG...]

Runs CMD inside a private user and mount namespace with one size-limited
tmpfs mounted for every --tmpfs option. Each NAME is exported into CMD's
environment set to the absolute path of its mount, e.g.

    tmptmpfs run --tmpfs TMP=10m -- bash -c 'echo hi > \"$TMP/f\"'

SIZE is a tmpfs size option: 10m, 512k, 1g, 100% ...
The tmpfs mounts (and the directories holding them) live only for as long
as CMD does; they are never visible in the host mount namespace.
";

/// A `--tmpfs NAME=SIZE` request.
struct Mount {
    name: String,
    size: String,
}

struct Plan {
    mounts: Vec<Mount>,
    cmd: OsString,
    args: Vec<OsString>,
}

struct Failure {
    code: i32,
    msg: String,
}

fn fail(code: i32, msg: impl Into<String>) -> Failure {
    Failure {
        code,
        msg: msg.into(),
    }
}

fn errno() -> String {
    io::Error::last_os_error().to_string()
}

fn main() {
    let argv: Vec<OsString> = env::args_os().skip(1).collect();

    if let Some(first) = argv.first() {
        let first = first.to_string_lossy();
        if first == "-h" || first == "--help" {
            print!("{}", USAGE);
            process::exit(0);
        }
    }

    let plan = match parse(&argv) {
        Ok(plan) => plan,
        Err(msg) => {
            eprintln!("tmptmpfs: {}", msg);
            eprint!("{}", USAGE);
            process::exit(2);
        }
    };

    let failure = run(&plan);
    eprintln!("tmptmpfs: {}", failure.msg);
    process::exit(failure.code);
}

fn parse(argv: &[OsString]) -> Result<Plan, String> {
    let mut mounts = Vec::new();

    let first = match argv.first() {
        None => return Err("missing subcommand (expected 'run')".to_owned()),
        Some(first) => first.to_string_lossy(),
    };
    if first != "run" {
        return Err(format!(
            "unknown subcommand '{}'; only 'run' is supported",
            first
        ));
    }

    let mut i = 1;

    while i < argv.len() {
        let arg = argv[i].to_string_lossy().into_owned();

        if arg == "--" {
            i += 1;
            break;
        } else if arg == "--tmpfs" {
            i += 1;
            if i >= argv.len() {
                return Err("--tmpfs requires a NAME=SIZE argument".to_owned());
            }
            mounts.push(parse_tmpfs(&argv[i].to_string_lossy())?);
            i += 1;
        } else if let Some(rest) = arg.strip_prefix("--tmpfs=") {
            mounts.push(parse_tmpfs(rest)?);
            i += 1;
        } else {
            return Err(format!("unexpected argument '{}'", arg));
        }
    }

    let rest = &argv[i..];
    if rest.is_empty() {
        return Err("missing '-- CMD [ARG...]'".to_owned());
    }

    let mut iter = rest.iter();
    let cmd = iter.next().unwrap().clone();
    let args = iter.cloned().collect();

    Ok(Plan { mounts, cmd, args })
}

fn parse_tmpfs(spec: &str) -> Result<Mount, String> {
    let (name, size) = match spec.split_once('=') {
        Some(pair) => pair,
        None => return Err(format!("expected NAME=SIZE, got '{}'", spec)),
    };

    if name.is_empty() {
        return Err(format!("empty NAME in '{}'", spec));
    }
    if name == "." || name == ".." || name.contains('/') {
        return Err(format!("invalid NAME '{}' in '{}'", name, spec));
    }
    if name.chars().any(|c| c.is_whitespace() || c == '\0') {
        return Err(format!("invalid NAME '{}' in '{}'", name, spec));
    }
    if size.is_empty() {
        return Err(format!("empty SIZE in '{}'", spec));
    }
    // SIZE becomes part of the tmpfs mount option string, so it must not be
    // able to smuggle in extra comma separated options.
    if size.contains(',') || size.chars().any(|c| c.is_whitespace() || c == '\0') {
        return Err(format!("invalid SIZE '{}' in '{}'", size, spec));
    }

    Ok(Mount {
        name: name.to_owned(),
        size: size.to_owned(),
    })
}

/// Everything below runs with the namespace already set up. It only returns
/// if `exec` fails, so the returned value is always a failure.
fn run(plan: &Plan) -> Failure {
    // Capture the *outer* identity before unsharing: after CLONE_NEWUSER
    // geteuid() reports an unmapped (overflow) uid until a map is written.
    let uid = unsafe { libc::geteuid() };
    let gid = unsafe { libc::getegid() };

    // 1. New user namespace.
    if unsafe { libc::unshare(libc::CLONE_NEWUSER) } != 0 {
        return fail(1, format!("unshare(CLONE_NEWUSER) failed: {}", errno()));
    }

    // 2. Map the caller onto uid/gid 0 inside the namespace.
    //
    //    The namespace *must* end up with a mapping: with an empty uid_map
    //    every inode created in the tmpfs we mount fails with EOVERFLOW, so
    //    the write is skipped only when the kernel has already mapped us.
    //
    //    For a caller that is already uid 0 this writes the identity map
    //    "0 0 1", which is also the unprivileged "map my own uid" case. A
    //    map whose lower id is 0 additionally needs CAP_SETFCAP in the
    //    parent namespace; if the kernel refuses the write, the EPERM is
    //    reported here rather than surfacing later as a confusing EOVERFLOW
    //    from the first mkdir.
    if !ids_are_mapped() {
        if let Err(f) = write_proc("/proc/self/setgroups", b"deny\n", true) {
            return f;
        }
        let uid_map = format!("0 {} 1\n", uid);
        if let Err(f) = write_proc("/proc/self/uid_map", uid_map.as_bytes(), false) {
            return f;
        }
        let gid_map = format!("0 {} 1\n", gid);
        if let Err(f) = write_proc("/proc/self/gid_map", gid_map.as_bytes(), false) {
            return f;
        }
    }

    // 3. New mount namespace, with propagation private so nothing we mount
    //    can ever show up in the host's mount table.
    if unsafe { libc::unshare(libc::CLONE_NEWNS) } != 0 {
        return fail(1, format!("unshare(CLONE_NEWNS) failed: {}", errno()));
    }
    let slash = cstr("/");
    let flags = libc::MS_REC | libc::MS_PRIVATE;
    if unsafe { libc::mount(ptr::null(), slash.as_ptr(), ptr::null(), flags, ptr::null()) } != 0 {
        return fail(
            1,
            format!("mount(NULL, \"/\", MS_REC|MS_PRIVATE) failed: {}", errno()),
        );
    }

    // 4. A private tmpfs to hold the mount points. Creating the mount point
    //    directories inside it means they, and the mounts on them, vanish
    //    with the namespace: no /tmp/tmptmpfs/<pid> directories are left
    //    behind on the host. Only the (empty) anchor directory itself
    //    persists, and only the first time it is used.
    let anchor = mount_root();
    if let Err(e) = fs::create_dir_all(&anchor) {
        return fail(1, format!("create_dir_all({}): {}", anchor.display(), e));
    }

    if let Err(f) = mount_tmpfs(&anchor, "mode=0700") {
        return f;
    }

    let mut exports: Vec<(&str, PathBuf)> = Vec::new();
    for m in &plan.mounts {
        if exports.iter().any(|(name, _)| *name == m.name.as_str()) {
            return fail(2, format!("duplicate --tmpfs name '{}'", m.name));
        }

        let dir = anchor.join(&m.name);
        if let Err(e) = fs::create_dir(&dir) {
            return fail(1, format!("create_dir({}): {}", dir.display(), e));
        }
        if let Err(f) = mount_tmpfs(&dir, &format!("size={}", m.size)) {
            return f;
        }

        exports.push((m.name.as_str(), dir));
    }

    // 5. Hand the mount paths to the child.
    for (name, dir) in &exports {
        env::set_var(name, dir);
    }

    // 6. Replace this process with CMD, so its exit status and signals are
    //    passed straight through to our caller.
    let err = Command::new(&plan.cmd).args(&plan.args).exec();
    fail(127, format!("exec '{}': {}", plan.cmd.to_string_lossy(), err))
}

fn mount_tmpfs(target: &Path, options: &str) -> Result<(), Failure> {
    let source = cstr("tmpfs");
    let fstype = cstr("tmpfs");

    let data = match CString::new(options) {
        Ok(data) => data,
        Err(_) => return Err(fail(2, format!("invalid mount options '{}'", options))),
    };
    let path = match CString::new(target.as_os_str().as_bytes()) {
        Ok(path) => path,
        Err(_) => {
            return Err(fail(
                2,
                format!("mount point contains NUL: {}", target.display()),
            ))
        }
    };

    let rc = unsafe {
        libc::mount(
            source.as_ptr(),
            path.as_ptr(),
            fstype.as_ptr(),
            0,
            data.as_ptr() as *const libc::c_void,
        )
    };

    if rc != 0 {
        return Err(fail(
            1,
            format!(
                "mount(tmpfs, {}, {}) failed: {}",
                target.display(),
                options,
                errno()
            ),
        ));
    }

    Ok(())
}

/// Write a single line to a procfs control file. `optional` is for files
/// that older kernels do not have, like /proc/self/setgroups.
fn write_proc(path: &str, data: &[u8], optional: bool) -> Result<(), Failure> {
    let mut file = match OpenOptions::new().write(true).open(path) {
        Ok(file) => file,
        Err(e) => {
            if optional && e.kind() == io::ErrorKind::NotFound {
                return Ok(());
            }
            return Err(fail(1, format!("open {}: {}", path, e)));
        }
    };

    match file.write_all(data) {
        Ok(()) => Ok(()),
        Err(_) if optional => Ok(()),
        Err(e) => Err(fail(1, format!("write {}: {}", path, e))),
    }
}

/// Does the current user namespace already have a uid mapping?
fn ids_are_mapped() -> bool {
    fs::read_to_string("/proc/self/uid_map")
        .map(|text| !text.trim().is_empty())
        .unwrap_or(false)
}

fn cstr(text: &str) -> CString {
    CString::new(text).expect("literal without NUL")
}

/// Directory that holds the (namespace-private) tmpfs mount points.
///
/// This must always be absolute and free of trailing slashes: consumers feed
/// the exported paths to `Path.expand/1` and `readlink -f`, and a relative or
/// slash-terminated base makes in-tree relative symlinks look like escapes.
/// `TMPDIR` is untrusted input, so it is normalised here.
fn mount_root() -> PathBuf {
    let base = env::temp_dir();
    let base = if base.is_absolute() {
        base
    } else {
        PathBuf::from("/tmp")
    };
    base.components().collect::<PathBuf>().join("tmptmpfs")
}
