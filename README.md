# Gentoo Homelab

Dokumentacja + skrypty z instalacji i konfiguracji Gentoo na VM w Proxmoksie.
Cel: nauka Linuksa "od zera" (kernel, portage, USE flags) + materiał do CV.

## Status

- [x] VM stworzona w Proxmoksie (System + Disks tab skonfigurowane)
- [x] ISO Gentoo minimal install podpięte
- [x] Partycjonowanie dysku (GPT + btrfs, subvolumes `@`/`@home`)
- [x] Stage3 rozpakowany
- [x] Chroot + base config (make.conf, profil, portage sync)
- [x] Kernel (ręczna konfiguracja — `make defconfig` + `menuconfig`, skompilowany i zainstalowany)
- [x] Bootloader (GRUB, UEFI, bez Secure Boot)
- [x] `/etc/fstab`
- [x] Pierwszy boot do zainstalowanego systemu (działa, mimo pozornie zamrożonego ekranu graficznego — patrz `notes/08`)
- [x] Sieć (systemd-networkd + DHCP), SSH (klucz + `sudo`, `PermitRootLogin no`, hasło roota zablokowane)
- [x] Zwykły użytkownik (`daniel`, grupa `wheel`) + `sudo` + klucz SSH
- [x] Narzędzia systemowe (mlocate, bash-completion, btrfs-progs, dosfstools, gentoolkit, fstrim.timer)
- [x] Qemu guest agent (`app-emulation/qemu-guest-agent`, jednostka `static`, aktywowana przez `BindTo=` na urządzeniu virtio-serial — potwierdzone `qm agent ping`)
- [x] GUI: i3 (X11) + `Xvfb`/`x11vnc`, dostęp zdalny przez tunel SSH (`notes/10`)

**Podstawowa instalacja + GUI zakończone.** Zostało (opcjonalnie, kosmetyczne): zbadanie
dlaczego ekran graficzny Proxmoksa nie pokazuje obrazu przez Virtio GPU/DRM mimo że system
działa poprawnie (`notes/08`) — nieblokujące, obejście przez zdalny VNC już działa (`notes/10`).

## Struktura repo

- `notes/` — decyzje konfiguracyjne i dlaczego (Proxmox VM, partycjonowanie, kernel, itd.)
- `scripts/` — skrypty pomocnicze uruchamiane w trakcie instalacji (z live ISO / z chroota / z zainstalowanego systemu)

## Środowisko

- Proxmox VE, VM: q35 + OVMF (UEFI, bez Secure Boot, bez TPM)
- Init system: **systemd**
- Storage: `local-lvm`, dysk 64 GiB (thin-provisioned)
