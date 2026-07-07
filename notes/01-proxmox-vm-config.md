# VM config w Proxmoksie — decyzje i dlaczego

## System tab

| Pole | Wartość | Dlaczego |
|---|---|---|
| Machine | `q35` | Nowoczesny chipset z PCIe (zamiast i440fx z lat 90.). Wymagane, jeśli kiedyś zechcę zrobić GPU passthrough. |
| BIOS | `OVMF (UEFI)` | Realia dzisiejszych maszyn (wszystkie nowe komputery bootują UEFI). Uczy partycji ESP, `efibootmgr`, GRUB-UEFI/systemd-boot. |
| Add EFI Disk | tak, "Pre-Enroll keys" **odznaczone** | Bez pre-enroll = Secure Boot nieaktywny. Ręcznie budowany kernel Gentoo nie jest podpisany — z aktywnym Secure Boot dostałbym "Security Violation" i VM by nie zabootowała. |
| Add TPM | **odznaczone** | Niepotrzebne na start. TPM ma sens dopiero przy LUKS+TPM albo measured boot — osobny projekt na później. |
| SCSI Controller | `VirtIO SCSI single` | Paravirtualizowany kontroler, najlepsza wydajność I/O. "single" = jeden kontroler na dysk, każdy dostaje własny iothread. |
| Qemu Agent | zaznaczone | Czysty shutdown z Proxmoksa, raportowanie IP, filesystem freeze przy snapshotach (spójne backupy). Wymaga później `app-emulation/qemu-guest-agent` w guest OS. |

**Ważne dla kernela:** VirtIO wymaga wkompilowania sterowników (`CONFIG_VIRTIO_BLK`, `CONFIG_VIRTIO_SCSI`, `CONFIG_VIRTIO_PCI`) — inaczej dysk nie zostanie wykryty przy ręcznej konfiguracji kernela (genkernel robi to automatycznie).

## Disks tab

| Pole | Wartość | Dlaczego |
|---|---|---|
| Storage | `local-lvm` | LVM thin pool — pozwala na `Discard`/TRIM i łatwy online resize później. |
| Disk size | 64 GiB | Zapas na system bazowy + kompilacje (thin provisioning, więc realnie zajmuje tyle ile faktycznie użyte). Można dalej rozszerzyć w locie (`qm resize` + resize w gościu). |
| Discard | **zaznaczone** | TRIM dla thin-provisioningu — bez tego skasowane pliki w guest nie zwalniają realnie miejsca na hoście. Wymaga `fstrim` (timer/cron) w Gentoo po instalacji. |
| SSD emulation | zaznaczone, jeśli storage fizycznie jest na SSD/NVMe | Informuje gościa, że to nie dysk talerzowy — inny scheduler I/O. |
| Cache | `Default (No cache)` | Bezpieczne i wydajne z VirtIO SCSI — dane idą przez O_DIRECT, cache zarządzany przez gościa i backend. |
| IO thread | zaznaczone | Odciąża główny wątek QEMU — osobny wątek I/O per dysk. |
| Async IO | `io_uring` | Najnowszy, najwydajniejszy backend I/O na współczesnym jądrze hosta. |
| Backup | zaznaczone | VM wchodzi do `vzdump` — siatka bezpieczeństwa przy eksperymentach z kernelem. |

## Init system: systemd

Wybrane zamiast OpenRC — spójne z resztą stacku (Fedora), bliżej "produkcyjnych" realiów.
Decyduje o wyborze stage3: **stage3-amd64-systemd** (nie -openrc).

## Do zrobienia w kolejnych krokach

1. Zakładka **CPU** — ustawić `host` (żeby `-march=native` działało w `make.conf`), dobrać liczbę vCPU pod `MAKEOPTS`.
2. Zakładka **OS** — podpiąć Gentoo minimal install ISO jako CD-ROM.
3. Boot z ISO → partycjonowanie (GPT: ESP + swap + root) → patrz `02-partitioning.md` (TODO).
4. `scripts/stage3-bootstrap.sh` — pobranie i rozpakowanie stage3-amd64-systemd.
