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
- [ ] `/etc/fstab` (w trakcie — patrz `notes/07`)
- [ ] Pierwszy boot do zainstalowanego systemu
- [ ] Sieć, użytkownik, SSH
- [ ] Qemu guest agent

## Struktura repo

- `notes/` — decyzje konfiguracyjne i dlaczego (Proxmox VM, partycjonowanie, kernel, itd.)
- `scripts/` — skrypty pomocnicze uruchamiane w trakcie instalacji (z live ISO / z chroota)

## Środowisko

- Proxmox VE, VM: q35 + OVMF (UEFI, bez Secure Boot, bez TPM)
- Init system: **systemd**
- Storage: `local-lvm`, dysk 64 GiB (thin-provisioned)
