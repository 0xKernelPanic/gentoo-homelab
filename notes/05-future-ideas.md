# Pomysły na przyszłość — świadomie odłożone

Rzeczy napotkane przy okazji konfiguracji kernela/make.conf, które są ciekawe i przydatne,
ale świadomie **nie** dodane teraz — zgodnie z zasadą stosowaną w całym projekcie: dodajemy
funkcjonalność, kiedy faktycznie jest potrzebna, nie na zapas "może się przyda".

| Technologia | Po co | Kiedy dodać | Gdzie w kernelu |
|---|---|---|---|
| **WireGuard** | Szybki VPN wbudowany w kernel (szybszy niż OpenVPN, bo cały tunel/kryptografia żyje w kernel space, nie userspace) | Gdy zechcesz dostępu do homelabu spoza sieci domowej | `Device Drivers → Network device support → WireGuard secure network tunnel` |
| **veth / macvlan / OverlayFS** | `veth` — para wirtualnych interfejsów łącząca kontener z hostem. `OverlayFS` — filesystem nakładkowy, którego używają Docker/Podman/containerd do warstwowania obrazów | Gdy postawisz Dockera/Podmana na tej VM | `Network device support → Virtual ethernet pair device`; `File systems → Overlay filesystem support` |
| **FUSE** | Filesystemy w userspace bez pisania sterownika kernela — fundament pod `sshfs` (montowanie zdalnego katalogu przez SSH) czy `rclone mount` (chmura jako dysk) | Gdy zechcesz montować zdalne/chmurowe zasoby | `File systems → FUSE (Filesystem in Userspace) support` |
| **dm-crypt (LUKS)** | Szyfrowanie całego dysku/partycji na poziomie bloków | Gdy zdecydujesz się szyfrować **root** — wymaga wtedy initramfs (patrz `notes/04`, sekcja o initramfs), bo cryptsetup musi się uruchomić zanim root zostanie zamontowany. Szyfrowanie **dodatkowego wolumenu danych** (nie-root) nie wymaga initramfs — wystarczy `/etc/crypttab` | `Device Drivers → Multiple devices driver support (RAID and LVM) → Device Mapper support → Crypt target` (cała ta kategoria jest obecnie wyłączona) |
| **fscrypt / fsverity** | Szyfrowanie/weryfikacja integralności **per plik/katalog**, nie całego dysku — alternatywa dla LUKS (tak działa szyfrowanie danych w Androidzie/ChromeOS) | Gdy chcesz szyfrować/weryfikować tylko wybrane dane, nie cały dysk | `File systems → FS Encryption` / `FS Verity` |
| **USB Serial Converter** | Sterowniki do kabli USB-RS232 (FTDI, Prolific PL2303, CP210x) | Gdy kupisz kabel konsolowy do zarządzania switchem/routerem po serial | `Device Drivers → USB support → USB port drivers → USB Serial Converter support` |
| **USB/IP** | Udostępnianie urządzenia USB przez sieć, jakby było podłączone lokalnie na innej maszynie | Ciekawa opcja, gdyby dongle USB miał być używany zdalnie z innego serwera w homelabie | `Device Drivers → USB support → USB Imaging devices → USB/IP support` |

Wszystkie powyższe **nie wymagają initramfs ani przebudowy całego `vmlinuz`** (poza dm-crypt na
roocie) — wystarczy wrócić do `/usr/src/linux`, `make menuconfig`, włączyć jako moduł (`=m`),
`make modules && make modules_install`, `modprobe <moduł>`. Zero potrzeby robić to na zapas teraz.
