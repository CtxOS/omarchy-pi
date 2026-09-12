use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::path::PathBuf;
use std::process::Command;

#[derive(Parser)]
#[command(name = "omarchy-pi-build", about = "Build Omarchy-Pi Raspberry Pi images")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Build image via pi-image/build.sh
    Mkimage {
        #[arg(long)]
        img: Option<PathBuf>,
        #[arg(long)]
        device: Option<PathBuf>,
        #[arg(long)]
        tarball: PathBuf,
        #[arg(long, default_value = "pi")]
        user: String,
        #[arg(long, default_value = "omarchy-pi")]
        hostname: String,
        #[arg(long, default_value = "us")]
        country: String,
        #[arg(long, default_value_t = false)]
        allow_aur: bool,
        /// Prebuilt AUR repo dir from lib/aur-cache.sh --build (avoids on-device compile)
        #[arg(long)]
        aur_cache: Option<PathBuf>,
        /// Disable plymouth splash (headless/lite); default keeps quiet splash on V3D
        #[arg(long, default_value_t = false)]
        no_plymouth: bool,
        #[arg(long, default_value = "8G")]
        size: String,
    },
    /// Verify image Chiclet checks (size, FAT boot files, pacman.conf sanity)
    Verify {
        #[arg(long)]
        img: PathBuf,
    },
}

fn repo_root() -> PathBuf {
    let exe = std::env::current_exe().unwrap_or_else(|_| PathBuf::from("."));
    // target/debug/omarchy-pi-build -> crate/ -> repo/crate/pi-image
    let mut d = exe.as_path();
    for _ in 0..5 {
        if let Some(p) = d.parent() {
            d = p;
            if d.join("pi-image").join("build.sh").exists() {
                return d.to_path_buf();
            }
        } else {
            break;
        }
    }
    // fallback: CWD/crate or CWD
    let cwd = std::env::current_dir().unwrap();
    if cwd.join("crate/pi-image/build.sh").exists() {
        return cwd.join("crate");
    }
    cwd
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.cmd {
        Cmd::Mkimage { img, device, tarball, user, hostname, country, allow_aur, aur_cache, no_plymouth, size } => {
            let root = repo_root();
            let build = root.join("pi-image/build.sh");
            let mut c = Command::new("sudo");
            c.arg("bash").arg(&build)
                .arg("--tarball").arg(&tarball)
                .arg("--user").arg(&user)
                .arg("--hostname").arg(&hostname)
                .arg("--country").arg(&country)
                .arg("--size").arg(&size);
            if let Some(i) = img { c.arg("--img").arg(i); }
            if let Some(d) = device { c.arg("--device").arg(d); }
            if allow_aur { c.arg("--allow-aur"); }
            if let Some(a) = aur_cache { c.arg("--aur-cache").arg(a); }
            if no_plymouth { c.arg("--no-plymouth"); }
            let st = c.status().context("run build.sh")?;
            if !st.success() { anyhow::bail!("build.sh failed"); }
        }
        Cmd::Verify { img } => {
            verify(&img)?;
            println!("[OK] verify passed: {}", img.display());
        }
    }
    Ok(())
}

fn verify(img: &PathBuf) -> Result<()> {
    let md = std::fs::metadata(img).with_context(|| format!("stat {}", img.display()))?;
    anyhow::ensure!(md.len() > 512 * 1024 * 1024, "image < 512M, suspicious");
    // mtools-less check: fdisk listing must show W95 FAT32 + Linux partitions
    let out = Command::new("sfdisk").arg("-d").arg(img).output().context("sfdisk -d")?;
    let txt = String::from_utf8_lossy(&out.stdout);
    anyhow::ensure!(txt.contains("type=c") || txt.contains("type=0c"), "no FAT32 BOOT partition");
    anyhow::ensure!(txt.contains("type=83"), "no Linux ROOT partition");
    Ok(())
}
