# Omarchy-Pi — Raspberry Pi Arch Build TODO

> Goal: produce flashable `omarchy-pi-rpi-aarch64.img` (Pi4/5, aarch64) from `ArchLinuxARM-rpi-aarch64-latest.tar.gz`.
> Current state: online converter (`boot.sh` -> `install.sh`) forked from `omarchy-mac`/Asahi, no image builder (`install/iso.sh` is dead stub).

## 0. Analysis summary

* Pipeline: `install.sh` sources `helpers` -> `preflight` -> `packaging` -> `config` -> `login` -> `post-install`.
* Already `aarch64` (`Architecture=aarch64`, ARM mirrors in `fix-mirrors.sh`, `helpers/set-arm-mirrors.sh`, `bin/omarchy-refresh-pacman-mirrorlist`), but Asahi/Apple-tied.
* Main blockers:
  1. `default/pacman/pacman.conf:73-89`, `fix-mirrors.sh:78-94`: `[asahi-alarm]`, dead `[community]`, bogus `[aur]` — Pi needs only `[core,extra,alarm]`.
  2. `omarchy-base.packages:8-18`: `linux-asahi, asahi-fwextract, asahi-desktop-meta, grub, efibootmgr` — Pi needs `linux-rpi, raspberrypi-bootloader, firmware-raspberrypi`.
  3. `omarchy-other.packages:21-53`: `limine*, linux, broadcom-wl, nvidia*, libva-intel/nvidia, macbook*, linux-t2*, apple-*` — drop/gate.
  4. `install/login/limine-snapper.sh` (x86_64-only) + `alt-bootloaders.sh` (UEFI/systemd-boot/grub/UKI) — no-op/wrong on Pi FAT `/boot/{config.txt,cmdline.txt,*.dtb,overlays/}`.
  5. `install/config/all.sh:22-28` only gates x86_64 Apple scripts; `bluetooth, printer, usb-autosuspend, ignore-power-button, fix-f13-audio` still run on Pi.
  6. `config/hypr/monitors.conf`: `GDK_SCALE=2` (retina) — Pi 1080p needs `1` + no-blur variant.
  7. AUR (`yay, typora, ttf-ia-writer, walker, impala, omarchy-chromium, obsidian`): heavy/`x86_64`-only, OOM on 1-2GB Pi — prefer `*-bin`, pre-build cache.

## 1. Crate layout to create

```text
crate/
  Cargo.toml  # omarchy-pi-build (clap, serde, anyhow) — wrapper over scripts
  src/main.rs # mkimage | bootstrap | chroot-run | package | verify
  pi-image/
    build.sh  # --device|--img --hostname --user --wifi-ssid --country
    lib/{partition.sh, bootstrap.sh, pacman-pi.sh, kernel-pi.sh, packages-pi.sh, boot-pi.sh, firstboot.sh}
    assets/{pacman.conf, mirrorlist, config.txt, cmdline.txt, mkinitcpio.conf.d-pi.conf}
    lists/{omarchy-pi.packages, omarchy-pi-aur-optional.packages}
    firstboot/{omarchy-pi-firstboot.service, growfs.sh, create-user.sh}
test/test-pi-image.sh
```

## 2. Tasks

### M1 — Sanitize pacman/repos
- [x] Write `crate/pi-image/assets/pacman.conf` (`[core,extra,alarm]` only, `Architecture=aarch64`, `ParallelDownloads=5`, `CheckSpace`).
- [x] Write `crate/pi-image/assets/mirrorlist` (`https://{ca,de,uk,us}.mirror.archlinuxarm.org`), drop 2023 `http://`-only `default/pacman/mirrorlist`.
- [x] Implement `lib/pacman-pi.sh`: `pacman-key --init --populate archlinuxarm`, `pacman -Syy`, strip `[asahi-alarm,community,aur,arch-mact2,omarchy]`.
- [x] Update `install/preflight/guard.sh`: detect `/proc/device-tree/model` `Raspberry` vs Asahi, warn on mismatch.
- [x] Fix `test/run-mirrorlist-sim.sh` stale `/workspaces/omarchy-mac` path.

### M2 — Kernel + boot (biggest)
- [x] Implement `lib/partition.sh`: `512M FAT32 BOOT (type c) + ext4 ROOT`, `mkfs.vfat -F32`, `bsdtar -xpf ArchLinuxARM-*.tar.gz -C ROOT; mv ROOT/boot/* BOOT/`.
- [x] Implement `lib/kernel-pi.sh`: remove `linux-asahi* asahi-* grub limine* efibootmgr broadcom-wl nvidia* intel* t2* macbook*`, install `linux-rpi linux-rpi-headers linux-firmware raspberrypi-bootloader firmware-raspberrypi mkinitcpio dosfstools btrfs-progs bluez bluez-utils wireless-regdb NetworkManager|iwd`.
- [x] Add `assets/config.txt` (`arm_64bit=1, kernel=kernel8.img, auto_initramfs=1, dtparam=audio=on, display_auto_detect=1, dtoverlay=vc4-kms-v3d`) + `assets/cmdline.txt` (`root=/dev/mmcblk0p2 rw rootwait quiet splash`).
- [x] Add `assets/mkinitcpio.conf.d-pi.conf` (`MODULES=(vc4 snd_bcm2835 brcmfmac)`, no `encrypt/btrfs-overlayfs` by default).
- [x] Gate `install/login/`: skip `limine-snapper.sh` + `alt-bootloaders.sh` grub/systemd-boot/efibootmgr path on Pi; keep `plymouth.sh` + `uwsm` if V3D allows, else labwc fallback. Preserve `BOOT/*.dtb,overlays/`.

### M3 — Packages + config
- [x] Fork `install/omarchy-base.packages` + `omarchy-other.packages` -> `crate/pi-image/lists/omarchy-pi.packages`: keep Hyprland stack + `mesa, vulkan-broadcom, libdrm, pipewire*, polkit-gnome, uwsm`; drop Apple/Intel/Nvidia/T2; mark `typora, obsidian, walker, impala, ttf-ia-writer, omarchy-chromium` as `OPTIONAL:`/ARM-allowlist, prefer `yay-bin, paru-bin`.
- [x] Pre-build AUR with `yay-bin` in builder cache; ship binary repo to avoid Pi compile (swap, `base-devel+git` still needed).
- [x] Add `install/config/hardware/pi.sh` (regdom, bluetooth, audio HDMI, disable `usb-autosuspend`/`ignore-power-button`/`power-profiles-daemon` tweaks); gate `printer, keyboard-backlight, f13-audio, fingerprint` off on Pi in `install/config/all.sh`.
- [x] Add Pi Hypr theme variant: `monitors.conf SCALE=1`, reduced blur/animations; wire into `bin/omarchy-theme-set`.
- [x] Update `README.md`: replace Asahi Alarm flow + Apple boot-loop link with Pi flash flow.

### M5 — AUR cache + Plymouth tune (current)
- [x] `lib/aur-cache.sh --build/--clean/--cache`: prebuild AUR-optional set into `pi-aur` repo (`repo-add`), skip pkgs with no `aarch64` arch, unprivileged `aurbuild` user.
- [x] `lib/packages-pi.sh`: fast path installs from `$AUR_CACHE/pi-aur.db` (no on-device compile), slow path falls back to yay-bin + <2GB swap warning.
- [x] `build.sh --aur-cache DIR --no-plymouth`: wires cache + `OMARCHY_PI_PLYMOUTH=0` headless toggle.
- [x] `lib/boot-pi.sh`: `OMARCHY_PI_PLYMOUTH=0` strips `quiet splash`, appends `plymouth.enable=0`, disables seamless-login; default keeps splash on V3D.
- [x] `assets/cmdline.txt`: fixed contradictory `splash + plymouth.enable=0` -> `quiet splash` by default.

### M4 — Builder crate + first-boot + verify
- [x] Implement `crate/pi-image/build.sh` + `lib/{bootstrap,packages-pi,boot-pi,firstboot}.sh` with `qemu-aarch64-static + systemd-nspawn/arch-chroot` support (native Pi + cross).
- [x] Implement Rust `omarchy-pi-build` CLI (`mkimage|bootstrap|verify`) calling scripts; `Cargo.toml` with `clap, serde, anyhow`.
- [x] Add `firstboot/omarchy-pi-firstboot.service`: `growpart/resize2fs`, `machine-id`, `user+wheel+sudo`, wifi country preseed, ssh keys.
- [x] Reuse installer in chroot with `OMARCHY_CHROOT_INSTALL=1 OMARCHY_FORCE_MIRROR_OVERWRITE=1` (run `preflight/packaging/config`, skip Pi-incompatible `login` steps).
- [x] Add `test/test-pi-image.sh`: partition check, `pacman -Syy`, kernel/boot files present, `hyprland` launches (QEMU smoke), mirrorlist sanity.
- [x] Add `.github/workflows/pi-image.yml` cross-build job.

### M6 — Image smoke without hardware (current)
- [x] `test/qemu-smoke.sh --img out.img [--boot]`: size + partition checks (graceful without sfdisk/root), BOOT file listing via loop/mtools/7z with clean skip, optional `qemu-system-aarch64 -M raspi4b` boot attempt.
- [x] README + CI wired to smoke script; `test-pi-image.sh` parity checks for it.

## 3. Verify

```bash
sudo ./crate/pi-image/build.sh --img out/omarchy-pi.img --user pi --country us
cargo run -p omarchy-pi-build -- verify --img out/omarchy-pi.img
bash test/test-pi-image.sh
bash test/qemu-smoke.sh --img out/omarchy-pi.img
```

## 4. Non-goals

* Pi3/Zero (`armv7l`), UEFI/GRUB/Limine on Pi, Chaotic-AUR re-add, `snapper+limine-snapper-sync` by default on SD.
