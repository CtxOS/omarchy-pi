
<img width="2560" height="1600" alt="screenshot-2025-09-23_23-46-46" src="https://github.com/user-attachments/assets/9d38cd95-ff1c-4bde-8756-52a94f391a9c" />

# Omarchy-mac installation steps

_Disclaimer: This guide is intended for Apple Silicon MacBooks M1/M2 and has only been tested on the M1 variant released in 2020. It is advised that you follow the instructions in the manual very carefully lest you risk bricking the MacBook or getting stuck in a Boot Loop (I will provide a fix for that as well in the end)._

## Step 1: Install Arch minimal from Asahi Alarm

Visit [https://asahi-alarm.org/](https://asahi-alarm.org/) and run the following script in your Terminal to start Asahi Alarm Installer:

```bash
curl https://asahi-alarm.org/installer-bootstrap.sh | sh
```

Once inside the Asahi Alarm Installer, please follow the on-screen instructions (very carefully). A few recommendations:

- Ideally, you should have at least `50 GB` available on your SSD that you can dedicate to the Linux partition.
- Choose `Asahi Arch Minimal` from the list of OS options the installer provides.

## Step 2: Initial Arch Linux Setup

After installation, boot into Arch Linux and perform the initial setup:

1. **Log into root** - username and password: `root`
2. **Configure wifi** - Run `nmtui` for network setup
3. **Update system** - Run `pacman -Syu`
4. **Install essential packages** - Run `pacman -S sudo git base-devel neovim chromium`

## Step 3: Create User Account

Create a new user account and configure sudo access:

1. **Create user** - `useradd -m -G wheel <username>`
2. **Set password** - `passwd <username>`
3. **Configure sudo** - `EDITOR=nano visudo`
4. **Enable wheel group** - Uncomment `%wheel ALL=(ALL:ALL) ALL`
5. **Save and exit** - Ctrl O, Enter, Ctrl X
6. **Switch to new user** - `su - <username>`

## Step 4: Install AUR Helper and Omarchy

As your new user, set up the AUR helper and install Omarchy:

1. **Install yay AUR helper**:
   ```bash
   git clone https://aur.archlinux.org/yay.git
   cd yay
   makepkg -si
   ```

2. **Create directories**:
   ```bash
   mkdir -p ~/.local/share
   cd ~/.local/share
   ```

3. **Clone and setup Omarchy**:
   ```bash
   git clone https://github.com/malik-na/omarchy-mac.git
   mv omarchy-mac omarchy
   cd omarchy
   bash install.sh
   ```

**Note**: If mirrors break during installation, run `bash fix-mirrors.sh` then run `install.sh` again.

## Mirrorlist updates

Omarchy may provide a recommended mirrorlist during install, but it will not silently overwrite an existing system mirrorlist. The installer and helper scripts follow a safe default:

- If `/etc/pacman.d/mirrorlist` does not exist, Omarchy will install the bundled default.
- If it exists, Omarchy will merge `Server = ...` entries from the bundled mirrorlist into the existing file so user-configured or distribution-specific mirrors (e.g., Arch Linux ARM) are preserved.

If you want to force a full overwrite you can either run the helper with `--force` and/or `--backup` to keep a timestamped backup, or set the environment variable `OMARCHY_FORCE_MIRROR_OVERWRITE=1` during install.

## Raspberry Pi image build (Pi4/5, aarch64)

```bash
# 1. Download ArchLinuxARM rpi tarball, then:
sudo ./crate/pi-image/build.sh \
  --img out/omarchy-pi.img --size 8G \
  --tarball ArchLinuxARM-rpi-aarch64-latest.tar.gz \
  --user pi --country us
# optional: --allow-aur --aur-cache /var/cache/omarchy-pi-aur \
#           --no-plymouth --wifi-ssid MyNet --wifi-psk secret

# Prebuild AUR set once on a fast host so Pis never compile (recommended for --allow-aur):
sudo AUR_CACHE=/var/cache/omarchy-pi-aur bash crate/pi-image/lib/aur-cache.sh --build
# Rust wrapper (parity with build.sh flags):
cargo run -p omarchy-pi-build --manifest-path crate/Cargo.toml -- mkimage \
  --tarball ArchLinuxARM-rpi-aarch64-latest.tar.gz --img out/omarchy-pi.img \
  --allow-aur --aur-cache /var/cache/omarchy-pi-aur

# 2. Flash (or use --device /dev/sdX directly):
sudo dd if=out/omarchy-pi.img of=/dev/sdX bs=4M status=progress conv=fsync

# 3. Verify / smoke checks:
bash test/test-pi-image.sh
bash test/qemu-smoke.sh --img out/omarchy-pi.img
# optional QEMU boot attempt (needs qemu-system-aarch64):
bash test/qemu-smoke.sh --img out/omarchy-pi.img --boot
cargo run -p omarchy-pi-build --manifest-path crate/Cargo.toml -- verify --img out/omarchy-pi.img
```

Pi notes: boots from FAT `/boot/{config.txt,cmdline.txt}` (no GRUB/Limine/UEFI —
`install/login` bootloader steps self-skip on Pi); Hypr defaults to 1x scale +
no-blur V3D profile (`config/hypr/monitors-pi.conf`, `default/hypr/looknfeel-pi.conf`);
first boot grows the rootfs and creates the user (`crate/pi-image/firstboot/`).

## Boot Loop Recovery (Apple/Asahi only)

In case you end up in a Boot Loop, here's the solution:

1. **Don't panic!**
2. **Follow this guide** – [https://support.apple.com/en-us/108900](https://support.apple.com/en-us/108900)

---

New updates coming soon...

(Find me on X/Twitter here - [https://x.com/tiredkebab](https://x.com/tiredkebab) )

- If you want to support - [coff.ee/malik2015no](coff.ee/malik2015no)



## Acknowledgements

Thanks @dhh for creating Omarchy.
