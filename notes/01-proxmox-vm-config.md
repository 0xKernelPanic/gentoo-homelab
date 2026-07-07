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

## CPU tab

| Pole | Wartość | Dlaczego |
|---|---|---|
| Type | `host` | Przepuszcza dokładny model/flagi fizycznego CPU do gościa (zamiast generycznego `x86-64-v2-AES`, który celowo ukrywa większość instrukcji dla kompatybilności live-migration). Wymagane, żeby `-march=native` w `make.conf` miało sens. Koszt: brak live migration między różnymi CPU — nieistotne przy jednym serwerze. |
| Sockets | 1 | Multi-socket/NUMA niepotrzebne przy jednym fizycznym CPU. |
| Cores | 8 | Host ma 16 wątków fizycznie, obciążenie ~0.6% (praktycznie idle). 8 dla Gentoo = 50/50 split — solidna równoległość kompilacji (`MAKEOPTS -j8`/`-j9`), a hostowi + innym VM zostaje pełne 8 wątków zapasu. |
| VCPUs | = Total cores (8) | Bez potrzeby hotplugu na start — prościej mieć równe Total cores. |
| CPU limit | unlimited | Brak potrzeby twardego capu przy takim zapasie mocy. |
| CPU units | 100 (domyślne) | Istotne dopiero przy konkurencji wielu VM o CPU — na razie nieistotne. |
| Enable NUMA | wyłączone | Jeden socket fizyczny — niepotrzebne. |
| CPU Affinity | All Cores | Pinowanie do konkretnych rdzeni hosta — zaawansowane, nieistotne teraz. |
| Extra CPU Flags | Default | `pcid` (taniej z KPTI/Meltdown-fix), `pdpe1gb` (hugepages 1GB), `spec-ctrl`/`ssbd` (sprzętowa mitygacja Spectre v2/v4). Mają sens tylko przy generycznych typach CPU, żeby dosztukować pojedynczą łatkę bez pełnego ujawnienia CPU. Z `host` — bez znaczenia, fizyczny CPU i tak przekazuje te flagi jeśli je ma. |

**Fizyczny host:** 16 wątków, obciążenie ~0.6% w momencie konfiguracji.

## Memory tab

| Pole | Wartość | Dlaczego |
|---|---|---|
| Memory | 12288 MiB (12 GiB) | Host ma 32 GB fizycznie, ale tylko ~18 GB *dostępne* (reszta już zajęta przez inne VM/usługi). 12 GB / 8 wątków kompilacji = ~1.5 GB/wątek, wystarcza na równoległy build bez swapowania w guest. Zostawia ~6 GB bufora z dostępnych 18 GB dla hosta. |
| Ballooning | wyłączone (Minimum memory = 12288, równe Memory) | Kompilacja to skokowe zużycie RAM — balloon driver reaguje z opóźnieniem, ryzyko OOM w środku długiego builda. Fixed alokacja = przewidywalność kosztem elastyczności, akceptowalne przy dostępnym zapasie. |
| Allow KSM | zaznaczone (domyślne) | Deduplikacja stron pamięci między VM na hoście, oszczędza RAM hosta. Bezpieczne u siebie (side-channel ryzyko dotyczy tylko multi-tenant chmur). Dla tej konkretnej VM niewielki zysk — dane kompilacji są unikalne/ulotne, nie pasują do stron innych VM — ale zero powodu, żeby wyłączać. |

**Uwaga:** to jest fixed rezerwacja — 12 GB jest zajęte cały czas gdy VM działa, niezależnie od realnego użycia. Jeśli zabraknie podczas cięższych pakietów, można podbić (stop → edit → start) albo zmniejszyć `MAKEOPTS -j`.

## Network tab

| Pole | Wartość | Dlaczego |
|---|---|---|
| No network device | odznaczone | Sieć potrzebna do stage3, sync portage, docelowo distcc. |
| Bridge | `vmbr0` | Standardowy bridge hosta. |
| VLAN Tag | no VLAN | Homelab to jedna płaska sieć, brak segmentacji VLAN. |
| Model | `VirtIO (paravirtualized)` | Najlepsza wydajność. Trzeci sterownik virtio do zapamiętania przy kernelu: `CONFIG_VIRTIO_NET` (obok `VIRTIO_BLK`/`SCSI`, `VIRTIO_PCI`) — bez niego karta sieciowa nie będzie widoczna po ręcznej konfiguracji jądra. |
| MAC address | `auto` | Bez potrzeby stałego MAC/DHCP reservation na razie. |
| Firewall | zaznaczone | Firewall Proxmoksa — sam checkbox nic nie blokuje, dopóki nie dodam reguł w Datacenter/VM → Firewall. `nftables` wewnątrz Gentoo to osobne, świadome ćwiczenie do zrobienia później. |
| Disconnect | odznaczone | Zaznaczone symulowałoby wyjęty kabel. |
| MTU | Same as bridge | Jumbo frames niepotrzebne w tej sieci. |
| Rate limit | unlimited | Brak powodu do throttlowania. |
| Multiqueue | **8** (= liczba vCPU) | Rozkłada obsługę ruchu sieciowego na wiele wątków. Bez znaczenia przy zwykłym pobieraniu stage3/portage, ale przyda się pod przyszły distcc cluster — zero kosztu ustawić teraz. |

## Init system: systemd

Wybrane zamiast OpenRC — spójne z resztą stacku (Fedora), bliżej "produkcyjnych" realiów.
Decyduje o wyborze stage3: **stage3-amd64-systemd** (nie -openrc).

## Do zrobienia w kolejnych krokach

1. Zakładka **Network** — konfiguracja sieci VM.
2. Zakładka **OS** — podpiąć Gentoo minimal install ISO jako CD-ROM.
3. Boot z ISO → partycjonowanie (GPT: ESP + swap + root) → patrz `02-partitioning.md` (TODO).
4. `scripts/stage3-bootstrap.sh` — pobranie i rozpakowanie stage3-amd64-systemd.
