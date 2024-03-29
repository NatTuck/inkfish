extern crate clap;
extern crate json;
extern crate libc;

use std::{fs, io, process, thread, time};
use std::path::PathBuf;
use std::process::Command;

use clap::{arg, Command as ClapCmd};

use json::JsonValue;


fn main() {
    let matches = ClapCmd::new("tmptmpfs")
        .about("Manage temporary tmpfs mounts")
        .arg_required_else_help(true)
        .subcommand(
            ClapCmd::new("list")
                .about("List active mounts")
        )
        .subcommand(
            ClapCmd::new("start")
                .about("Start a temporary mount")
                .arg(arg!(-t --time <SECS> "Duration mount will last")
                    .default_value("300"))
                .arg(arg!(-s --size <SIZE> "Max size of filesystem")
                    .default_value("10M"))
        )
        .subcommand(
            ClapCmd::new("clean")
                .about("Clean up old mounts")
        )
        .subcommand(
            ClapCmd::new("who")
                .about("Verify setuid config")
        )
        .get_matches();
            
    setuid_root();

    match matches.subcommand() {
        Some(("list", _opts)) => {
            make_base().unwrap();

            for mount in list_mounts().unwrap() {
                println!("{}", mount);
            }
        },
        Some(("start", opts)) => {
            let time: u32 =  opts.get_one::<String>("time").unwrap()
                .parse::<u32>().unwrap();
            let size: &str = opts.get_one::<String>("size").unwrap();
            let path = start_mount(time, size).unwrap();
            println!("{}", path);
        },
        Some(("clean", _opts)) => {
            clean_mounts().unwrap();
        },
        Some(("who", _opts)) => {
            let outp = Command::new("whoami")
                .output().unwrap().stdout;
            let text = std::str::from_utf8(&outp).unwrap();
            println!("whoami = {}", text);
        },
        _ => panic!("unmatched subcommand"),
    }
}

fn base_dir() -> PathBuf {
    let mut path = PathBuf::from("/tmp");
    path.push("tmptmpfs");
    path
}

fn mount_dir(pid: i32) -> PathBuf {
    let mut path = base_dir();
    path.push(format!("{}", pid));
    path
}

fn make_base() -> io::Result<()> {
    fs::create_dir_all(base_dir())
}

fn list_mounts() -> io::Result<Vec<String>> {
    let outp = Command::new("findmnt")
        .arg("-J")
        .output()?
        .stdout;
    let text = std::str::from_utf8(&outp).unwrap();
    let data = json::parse(text).unwrap();
    let base = base_dir().to_str().unwrap().to_owned();
    let ys = find_tt_mounts(&base, &data["filesystems"]);
    Ok(ys)
}

fn find_tt_mounts(base: &str, xs: &JsonValue) -> Vec<String> {
    let mut ys = vec![];
    for fs in xs.members() {
        if fs.has_key("children") {
            let zs = find_tt_mounts(&base, &fs["children"]);
            ys.extend(zs.into_iter());
        }
        if !fs.has_key("target") {
            continue;
        }

        let plen = base.len();
        let target = fs["target"].as_str().unwrap();
        if target.len() > plen && &target[0..plen] == base {
            ys.push(target.to_owned());
        }
    }
    ys
}

fn clean_mounts() -> io::Result<()> {
    let ms = list_mounts()?;
    let base = base_dir();

    for ent in fs::read_dir(base)? {
        let ent = ent?;
        let path = ent.path();
        if path.is_dir() {
            let pid = path.file_name().unwrap().to_str().unwrap().parse::<i32>().unwrap();
            if !is_alive(pid) {
                let pstr = path.to_str().unwrap().to_owned();

                if ms.contains(&pstr) {
                    match unmount(path.clone()) {
                        Ok(_) => {
                            let _ = std::fs::remove_dir(path);
                        },
                        Err(ee) => println!("unmount error: {:?}\n{:?}", &path, ee),
                    }
                }
            }
        }
    }

    Ok(())
}

fn is_alive(pid: i32) -> bool {
    unsafe {
        libc::kill(pid, 0) == 0
    }
}

fn close_fds() {
    unsafe {
        libc::close(0);
        libc::close(1);
        libc::close(2);
    }
}

fn start_mount(duration: u32, size: &str) -> io::Result<String> {
    let cpid = unsafe { libc::fork() };
    if cpid != 0 {
        let mdir = mount_dir(cpid);
        let mstr = mdir.to_str().unwrap().to_owned();
        loop {
            sleep_ms(100);
            let ms = list_mounts()?;
            if ms.contains(&mstr) {
                break;
            }
        }
        return Ok(mstr);
    }

    // Child process
    close_fds();

    let pid = process::id() as i32;
    mount(pid, size)?;

    sleep_ms(1000 * duration);

    let mdir = mount_dir(pid);
    unmount(mdir.clone())?;

    process::exit(0);
}

fn mount(pid: i32, size: &str) -> io::Result<()> {
    let path = mount_dir(pid);
    fs::create_dir_all(&path)?;
    let mut cmd = Command::new("mount");
    cmd.arg("-t")
       .arg("tmpfs")
       .arg("-o")
       .arg(format!("size={}", size))
       .arg("tmpfs")
       .arg(&path);

    //println!("cmd = [{:?}]", &cmd);

    let status = cmd.status()?;
    if status.success() {
        Ok(())
    }
    else {
        io_err("mount")
    }
}

fn unmount(path: PathBuf) -> io::Result<()> {
    let mut cmd = Command::new("umount");
    cmd.arg(&path);
    println!("{:?}", &cmd);
    let status = cmd.status()?;
    if status.success() {
        std::fs::remove_dir(&path).expect("rmdir");
        Ok(())
    }
    else {
        io_err("unmount")
    }
}

fn sleep_ms(ms: u32) {
    let pause = time::Duration::from_millis(ms.into());
    thread::sleep(pause);
}

fn io_err(text: &str) -> io::Result<()> {
    Err(io::Error::new(io::ErrorKind::Other, text))
}

fn setuid_root() {
    unsafe {
        let euid = libc::geteuid();
        if euid == 0 {
            let rv = libc::setuid(0);
            assert!(rv == 0);
        }
    }
}
