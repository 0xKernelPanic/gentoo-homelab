# Kompilacja kernela, moduły, GRUB — wykonane kroki

Kontynuacja `notes/04-kernel-config.md` (tam decyzje `menuconfig`) — tu przebieg kompilacji,
instalacji i podpięcia bootloadera.

## Kompilacja i instalacja kernela

```bash
cd /usr/src/linux
make -j8
make modules_install
make install
```

`make install` bez `sys-kernel/installkernel` (świadoma decyzja, `notes/04`) robi najprostszy
możliwy fallback: kopiuje obraz kernela jako zwykły plik **`/boot/vmlinuz`** (bez numeru
wersji w nazwie) i `/boot/System.map`. Komunikat `Cannot find LILO.` na końcu jest
nieszkodliwy — to relikt starego skryptu instalacyjnego kernela, który historycznie zawsze
próbował odświeżyć config LILO (bootloader sprzed GRUB-a); nieistotne, skoro używamy GRUB-a.

## GRUB

```bash
# w /etc/portage/make.conf:
GRUB_PLATFORMS="efi-64"

emerge --ask sys-boot/grub
grub-install --target=x86_64-efi --efi-directory=/efi --removable
grub-mkconfig -o /boot/grub/grub.cfg
```

`--removable` instaluje dodatkowo kopię pod uniwersalną ścieżką `\EFI\BOOT\BOOTX64.EFI`,
której szuka każdy UEFI nawet jeśli wpis w NVRAM (przez `efibootmgr`) z jakiegoś powodu się
nie zapisze poprawnie — tania polisa bezpieczeństwa w VM.

### Pułapka: `grub-mkconfig` nie widział kernela

`grep vmlinuz /boot/grub/grub.cfg` wracał pusty, mimo że kompilacja/instalacja przeszły bez
błędu. Przyczyna: skrypt wykrywania kerneli (`/etc/grub.d/10_linux`) szuka plików pasujących
do wzorca **`vmlinuz-*`** (z myślnikiem i czymkolwiek po nim — normalnie numer wersji, nadany
przez `installkernel`, którego świadomie nie mamy). Sam plik `vmlinuz` (bez sufiksu) nie pasuje
do tego wzorca, więc kernel był całkowicie pomijany przy generowaniu `grub.cfg`.

**Naprawa:**
```bash
mv /boot/vmlinuz /boot/vmlinuz-6.18.38-gentoo
mv /boot/System.map /boot/System.map-6.18.38-gentoo
grub-mkconfig -o /boot/grub/grub.cfg
```
Po tym `grep vmlinuz /boot/grub/grub.cfg` pokazuje poprawny wpis — potwierdzony konkretny
koszt decyzji "bez `installkernel`": trzeba ręcznie utrzymywać konwencję nazewniczą, żeby
skrypty GRUB-a w ogóle widziały kernel. Przy kolejnych własnoręcznych aktualizacjach kernela
(patrz `notes/06`, `make oldconfig`) — pamiętać o tym samym ręcznym `mv` po każdym
`make install`.

## Status na koniec dnia (do kontynuacji)

- [x] Kernel skompilowany, zainstalowany, wykrywany przez GRUB
- [x] GRUB zainstalowany na ESP (`/efi`), `grub.cfg` wygenerowany z poprawnym wpisem
- [ ] **`/etc/fstab`** — nie zrobione jeszcze. Trzeba: `blkid` → UUID/LABEL dla `/dev/sda1`
      (ESP, vfat), `/dev/sda2` (swap), `/dev/sda3` (btrfs, dwa wpisy: root z `subvol=@`,
      `/home` z `subvol=@home`, oba z `compress=zstd` — patrz `notes/02`)
- [ ] Wyjście z chroota, odmontowanie (`umount -R /mnt/gentoo`, `swapoff`), reboot VM
- [ ] Pierwszy boot do zainstalowanego systemu (weryfikacja: obraz na konsoli Proxmoksa dzięki
      Virtio GPU/DRM/FB/fbcon, klawiatura/mysz dzięki USB HID, dysk/root przez Virtio SCSI+Btrfs)
- [ ] Sieć, użytkownik, SSH, `qemu-guest-agent` (kolejne rozdziały Handbooka — nie zaczęte)
