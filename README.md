# Gentoo homelab

[![ShellCheck](https://github.com/0xKernelPanic/gentoo-homelab/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/0xKernelPanic/gentoo-homelab/actions/workflows/shellcheck.yml)

Gentoo Linux installed by hand on a Proxmox VM: a hand-configured kernel with no initramfs, btrfs with zstd compression, GRUB on UEFI, systemd, a hardened SSH setup and a remote i3 desktop over an SSH tunnel. The goal was to learn Linux from the ground up, so every decision is written down with the reason for it, and so is every trap I fell into on the way.

The notes are in Polish; this page is the English summary.

## What is in here

| | |
|---|---|
| [`notes/`](notes/) | ten chapters, from the VM settings to the desktop: each decision, the alternatives and why |
| [`scripts/stage3-bootstrap.sh`](scripts/stage3-bootstrap.sh) | from the live ISO: partitions the disk, creates the btrfs subvolumes, downloads stage3, **verifies its GPG signature and checksum**, unpacks it and prepares the chroot |
| [`scripts/finalize-system.sh`](scripts/finalize-system.sh) | on the booted system: tools, sudo for `wheel` through a `visudo`-checked drop-in, a regular user, `fstrim.timer`; then prints the manual steps that involve secrets |

## The system

| | |
|---|---|
| VM | Proxmox, q35 + OVMF (UEFI, no Secure Boot), `host` CPU type, 8 vCPU, 12 GiB fixed RAM, VirtIO SCSI single with io_uring and discard |
| Disk | GPT: ESP 512 MiB, swap 2 GiB, btrfs root with `compress=zstd` and `@` / `@home` subvolumes |
| Portage | `default/linux/amd64/23.0/systemd`, `-march=native -O2 -pipe`, `MAKEOPTS="-j8 -l9"` |
| Kernel | `gentoo-sources` 6.18, `make defconfig` trimmed in `menuconfig`, everything needed for the root built in (`=y`), so no initramfs; `make install` without `installkernel`, GRUB installed by hand |
| Network | `systemd-networkd` + DHCP, `systemd-resolved` |
| Access | SSH with a key only, root locked (`passwd -l root`, `PermitRootLogin no`), `sudo` for `wheel` |
| Desktop | i3 on `Xvfb` shared by `x11vnc` bound to localhost, reached through an SSH tunnel; a systemd unit starts it |
| Guest agent | `qemu-guest-agent`, confirmed with `qm agent ping` |

## Decisions worth a look

- **btrfs, not ZFS or ext4** ([02](notes/02-partitioning.md)): ZFS is an out-of-tree module, a real boot risk on a first hand-built kernel; btrfs is mainline and brings snapshots, checksums and transparent zstd compression, which speeds up I/O-bound compile workloads instead of only saving space.
- **No initramfs** ([04](notes/04-kernel-config.md)): the drivers for the root (VirtIO SCSI, btrfs) are built in. An initramfs becomes necessary only with LUKS on the root, so it waits until then.
- **Identifying drivers from `lspci`, not from "Kernel driver in use"** ([04](notes/04-kernel-config.md)): every VirtIO device shows `virtio-pci`, which is only the transport; the functional driver lives on the virtio bus. Also: the SCSI driver is `SCSI_VIRTIO`, not `VIRTIO_SCSI`.
- **`CONFIG_LEGACY_TIOCSTI` off** ([04](notes/04-kernel-config.md)): TIOCSTI lets a process type into another terminal, a known privilege-escalation and container-escape vector; free hardening on a non-hardened profile.
- **Fixed RAM, no ballooning** ([01](notes/01-proxmox-vm-config.md)): compiling uses memory in bursts, and the balloon driver reacts too late.
- **VNC only on localhost** ([10](notes/10-gui-i3-vnc.md)): VNC is unencrypted, so it never listens on the network; the SSH tunnel carries it.

## Problems I ran into and solved

- **GRUB did not see the kernel** ([07](notes/07-kernel-build-and-boot.md)): without `installkernel`, `make install` writes a bare `/boot/vmlinuz`, and `/etc/grub.d/10_linux` only matches `vmlinuz-*`. Renaming to the versioned name fixed it, and showed the cost of doing it by hand.
- **A "frozen" first boot that was not frozen** ([08](notes/08-first-boot-and-network.md)): the screen stopped at `Loading Linux`, but a serial console (`console=ttyS0`, `qm terminal`) showed a fully booted system. The real fault is the Virtio GPU never negotiating a display mode ([10](notes/10-gui-i3-vnc.md)): `status` is `unknown`, `modes` is empty, likely EDID between QEMU/OVMF and the guest.
- **SSH refused the correct root password** ([08](notes/08-first-boot-and-network.md)): `PermitRootLogin prohibit-password` allows keys only. Fixed properly later with a user, a key and root locked.
- **Locked out of sudo** ([09](notes/09-finalizing-and-hardening.md)): `pam_faillock` after three wrong passwords; `faillock --reset`.
- **TigerVNC sessions dying at once** ([10](notes/10-gui-i3-vnc.md)): newer TigerVNC starts sessions through `xinit`, which checks the `XFree86_VT` root-window property that a headless `Xvnc` does not have. Replaced with `Xvfb` + `x11vnc`.

## Notes

1. [Proxmox VM settings](notes/01-proxmox-vm-config.md)
2. [Partitioning and filesystems](notes/02-partitioning.md)
3. [Portage: profile and make.conf](notes/03-portage-base-config.md)
4. [Kernel configuration](notes/04-kernel-config.md)
5. [Ideas deliberately left for later](notes/05-future-ideas.md)
6. [General lessons about kernel configuration](notes/06-kernel-lessons.md)
7. [Building the kernel, modules, GRUB](notes/07-kernel-build-and-boot.md)
8. [First boot, network, SSH](notes/08-first-boot-and-network.md)
9. [Finishing and hardening](notes/09-finalizing-and-hardening.md)
10. [i3 desktop over VNC](notes/10-gui-i3-vnc.md)

## Status

The base system and the remote desktop are done. Open, and not blocking: the Proxmox graphical console stays blank (the Virtio GPU display-mode issue above). Next ideas are in [05](notes/05-future-ideas.md): WireGuard, containers, LUKS.

Every push runs [ShellCheck](.github/workflows/shellcheck.yml) on the scripts.

## Licence

Public domain ([The Unlicense](LICENSE)).
