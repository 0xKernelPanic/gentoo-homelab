# Gentoo Homelab

Dokumentacja + skrypty z instalacji i konfiguracji Gentoo na VM w Proxmoksie.
Cel: nauka Linuksa "od zera" (kernel, portage, USE flags) + materiał do CV.

## Status

- [x] VM stworzona w Proxmoksie (System + Disks tab skonfigurowane)
- [ ] ISO Gentoo minimal install podpięte
- [ ] Partycjonowanie dysku
- [ ] Stage3 rozpakowany
- [ ] Chroot + base config (make.conf, portage sync)
- [ ] Kernel (ręczna konfiguracja)
- [ ] Bootloader (UEFI, bez Secure Boot)
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
