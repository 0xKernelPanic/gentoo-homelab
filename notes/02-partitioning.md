# Partycjonowanie i filesystemy — decyzje i dlaczego

Wykonane ręcznie w live environment (Gentoo minimal install ISO), komenda po komendzie,
zanim spisane do `scripts/stage3-bootstrap.sh`.

## Schemat partycji (GPT, `sgdisk`)

| Partycja | Rozmiar | Typ GPT | Cel |
|---|---|---|---|
| `/dev/sda1` | 512 MiB | `ef00` (EFI System) | ESP pod UEFI/GRUB |
| `/dev/sda2` | 2 GiB | `8200` (Linux swap) | swap — siatka bezpieczeństwa, nie primary memory (VM ma 12 GB RAM) |
| `/dev/sda3` | reszta dysku (~61 GiB) | `8300` (Linux filesystem) | root |

**Uwaga:** kod typu partycji GPT (`8300`) jest generyczny dla "jakiegokolwiek Linuksowego filesystemu" — nie ma osobnego kodu dla btrfs. Wybór filesystemu dzieje się dopiero na etapie `mkfs.*`, partycjonowanie jest od niego niezależne.

## Filesystem root: **btrfs** (nie ext4)

Wybrane świadomie zamiast domyślnego ext4 — opcje rozważane: ext4, btrfs, XFS, ZFS.

**Dlaczego btrfs, nie ZFS:** ZFS wymaga modułu kernela spoza drzewa (out-of-tree, przez portage/dkms) — przy ręcznie budowanym kernelu na pierwszym incie Gentoo to istotnie podnosi ryzyko problemów z bootem. Btrfs jest mainline (w kernelu Linux), więc ten sam poziom ryzyka co ext4/XFS.

**Dlaczego btrfs, nie ext4/XFS:** nowoczesne funkcje przydatne właśnie na maszynie kompilującej dużo pakietów — wbudowane snapshoty (dodatkowa siatka bezpieczeństwa obok snapshotów samego Proxmoksa), checksumming danych, i przede wszystkim **kompresja transparentna**.

### Formatowanie

```bash
mkfs.vfat -F32 /dev/sda1
mkswap /dev/sda2
mkfs.btrfs -f -L rootfs /dev/sda3
```

### Montowanie

```bash
mount -o compress=zstd /dev/sda3 /mnt/gentoo
mkdir /mnt/gentoo/efi
mount /dev/sda1 /mnt/gentoo/efi
swapon /dev/sda2
```

`compress=zstd` — kompresuje transparentnie źródła/pliki `.o` w `/var/tmp/portage`, oszczędza miejsce na 64 GB dysku. Nie dotyczy ESP (`vfat` nie wspiera kompresji).

**Dlaczego kompresja tu realnie przyspiesza, a nie tylko oszczędza miejsce:** btrfs sam z siebie płaci pewien koszt wydajności za swoje funkcje — copy-on-write, wolumeny logiczne, snapshoty. Ale kompresja zstd działa na tyle szybko, że **odwraca ten bilans**: mniej danych fizycznie trafia na dysk, więc mniej czasu schodzi na samo I/O — a to ono, nie CPU, jest zwykle wąskim gardłem przy zapisie. W efekcie kompresja nie jest tylko oszczędnością miejsca, tylko realnym przyspieszeniem względem tego samego btrfs bez kompresji.

### Subvolumes: **na razie brak** (pojedynczy top-level subvolume)

Świadomie odłożone na później — podział na `@`/`@home`/`@var` (osobne snapshotowanie per katalog) to dobre rozszerzenie, ale nie na etapie pierwszego bootowania systemu. Zrobimy to jako kolejny krok, gdy system już wstanie.

**Aktualizacja:** ostatecznie root i `/home` są na subvolumes `@` i `@home` (patrz `/etc/fstab` w `notes/08`), a `scripts/stage3-bootstrap.sh` tworzy je od razu przy instalacji.

## Do zapamiętania przy konfiguracji kernela

- `CONFIG_BTRFS_FS=y` — **na stałe wkompilowane**, nie jako moduł (root fs musi być czytelny zanim jakikolwiek moduł się załaduje, chyba że użyjesz initramfs).
- `CONFIG_VIRTIO_BLK`, `CONFIG_VIRTIO_SCSI`, `CONFIG_VIRTIO_PCI`, `CONFIG_VIRTIO_NET` — z wcześniejszych ustaleń (System/Network tab), inaczej dysk/sieć nie zostaną wykryte.

## Do zapamiętania przy `fstab`

Wpis dla root powinien zawierać opcję `compress=zstd` (tak jak przy ręcznym mountowaniu wyżej) — inaczej po restarcie kompresja nie będzie aktywna.
