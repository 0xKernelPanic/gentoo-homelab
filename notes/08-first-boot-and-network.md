# Pierwszy boot, sieć, SSH — przebieg i pułapki

## `/etc/fstab`

```
# root
UUID=87b1e4c9-e026-411d-95c8-6696d3523f02  /       btrfs   subvol=@,compress=zstd        0 0

# home
UUID=87b1e4c9-e026-411d-95c8-6696d3523f02  /home   btrfs   subvol=@home,compress=zstd    0 0

# ESP
UUID=6D8D-AB6F                              /efi    vfat    defaults                      0 2

# swap
UUID=e4231520-4248-425a-a743-29dd5ba4c55f  none    swap    sw                            0 0
```

Root i `/home` celowo mają **ten sam UUID** — to nie błąd, subvolumes `@`/`@home` nie są osobnymi
urządzeniami blokowymi, tylko logicznym podziałem w jednym Btrfs na `/dev/sda3`. `pass=0` dla
obu wpisów Btrfs (fsck.btrfs to zaślepka, Btrfs ma własny mechanizm spójności).

## Hostname, sieć, systemd

- Hostname: `gentoo-homelab` (`/etc/hostname` + wpis w `/etc/hosts`)
- Sieć: `systemd-networkd` + DHCP (`/etc/systemd/network/50-dhcp.network`, `Name=en*`), zamiast
  `NetworkManager` — spójne z wyborem systemd, VM ma tylko przewodowy Virtio NIC (bez WiFi,
  więc przewaga NetworkManagera nad `networkd` jest tu zerowa)
- DNS: `systemd-resolved` włączone, `/etc/resolv.conf` → symlink do `stub-resolv.conf`
  (**uwaga**: `arch-chroot` automatycznie bind-mountuje `/etc/resolv.conf` z hosta live ISO —
  trzeba było najpierw `umount /etc/resolv.conf` zanim dało się podmienić na symlink)
- `systemd-machine-id-setup` + `systemctl preset-all --preset-mode=enable-only`
- Hasło roota: uwaga, domyślnie było **zablokowane (`L`)** w świeżym stage3 — `passwd root`
  konieczne przed pierwszym bootem, inaczej brak możliwości zalogowania się w ogóle

## Pierwszy boot — pozorne zawieszenie na ekranie graficznym

Po restarcie ekran (konsola VNC/SPICE Proxmoksa) zamarzał na `Loading Linux 6.18.38-gentoo ...`
i nic więcej się nie działo — wyglądało na zawieszony kernel. **To był fałszywy alarm.**

Diagnoza przez `qm terminal <vmid>` (konsola szeregowa, dodana jako Hardware → Serial Port →
Socket w Proxmoksie, plus jednorazowe dopisanie `console=ttyS0,115200n8` do linii `linux` w
edycji GRUB) pokazała **normalny, poprawny log zamykania systemd** po wysłaniu `Stop` z
Proxmoksa — czyli system **w rzeczywistości poprawnie wystartował**, doszedł do
`multi-user.target`/`graphical.target`, sieć działała, tylko **nic z tego nie było widoczne**
na ekranie graficznym.

**Wniosek: problem jest kosmetyczny (renderowanie obrazu przez Virtio GPU/DRM/fbcon), nie
funkcjonalny.** System jest w pełni sprawny mimo czarnego ekranu. Do zbadania później (dlaczego
konkretnie DRM/Virtio GPU nie odświeża obrazu na konsoli Proxmoksa) — nie blokuje dalszej pracy,
bo mamy SSH.

`nomodeset` jako test diagnostyczny **nie był miarodajny** — czyste UEFI (bez CSM/legacy BIOS)
często nie ma żadnego awaryjnego trybu tekstowego VGA, więc wyłączenie DRM przez `nomodeset`
mogło zabrać jedyną (nawet niedziałającą) ścieżkę wyświetlania, zamiast pokazać coś prostszego.

## SSH — pułapka `PermitRootLogin`

`net-misc/openssh` + `systemctl enable sshd` — po restarcie `ssh root@<IP>` **pytał o hasło,
ale zawsze je odrzucał**, mimo poprawnego hasła. Przyczyna: domyślne `PermitRootLogin
prohibit-password` w OpenSSH pozwala rootowi logować się **tylko kluczem SSH, nigdy hasłem**,
niezależnie od poprawności hasła. Naprawione tymczasowo przez `PermitRootLogin yes` w
`/etc/ssh/sshd_config` + `systemctl restart sshd`, żeby uzyskać dostęp — **do zrobienia
docelowo lepiej: zwykły użytkownik + klucz SSH zamiast hasła na roocie**, i wyłączenie
`PermitRootLogin` całkowicie.

Zalogowano się do systemu **lokalnie** (przez `qm terminal` + `console=ttyS0` + login prompt na
serial getty) — to obejście, które pozwoliło poprawić `sshd_config` bez potrzeby wracania do
live ISO/chroota, skoro system sam w sobie działał poprawnie.
