# Ogólna wiedza o konfiguracji kernela — do zapamiętania

Wnioski z przechodzenia przez `make menuconfig` przy okazji `notes/04`, uogólnione poza
konkretną tę instalację — przydatne przy każdej przyszłej konfiguracji/aktualizacji kernela.

## Model mentalny

1. **`y`/`m`/`n`** — wbudowane na stałe / moduł ładowany później z dysku / wyłączone. Wszystko
   potrzebne *przed* zamontowaniem roota (bez initramfs) musi być `y`, nigdy `m`.
2. **Architektura warstwowa, powtarzająca się w całym kernelu**: magistrala (bus) → transport/
   kontroler hosta → klasa/protokół urządzenia → generyczny podsystem, z którego korzysta
   userspace. Przykłady: `PCI → virtio-pci → virtio_scsi → SCSI/BLK_DEV_SD`;
   `PCI/USB → UHCI/EHCI → USB HID → evdev`; `PCI → virtio-pci → virtio_gpu → DRM → FB → fbcon`.
3. **`Depends on` / `Selects`** w wynikach wyszukiwania menuconfig (`/`) — to jak namierzać
   łańcuchy zależności zamiast zgadywać: `Depends on` = co musi być spełnione niżej,
   `Selects` = co ta opcja wymusza automatycznie.
4. **Nazwy Kconfig bywają nieintuicyjne** (`SCSI_VIRTIO`, nie `VIRTIO_SCSI` — bo leży pod
   kategorią "SCSI device support", nie "VIRTIO"). Dlatego wyszukiwarka > pamięciowe błądzenie
   po strukturze menu.
5. **Nagłówki-kategorie producentów** (np. `[*] Intel devices` w Ethernet driver support) to
   tylko przełączniki widoczności podmenu — nie kompilują żadnego kodu same z siebie.
   Nieszkodliwe zostawić zaznaczone; liczą się tylko konkretne pozycje wewnątrz (`<*>`/`<M>`).

## Jak żyć z ręcznie skonfigurowanym kernelem długoterminowo

**`make oldconfig` / `make olddefconfig`** — przy aktualizacji do nowszej wersji
`gentoo-sources` **nie trzeba przechodzić przez cały ten proces od zera**:

```bash
cp /usr/src/linux-<stara-wersja>-gentoo/.config /usr/src/linux-<nowa-wersja>-gentoo/.config
cd /usr/src/linux-<nowa-wersja>-gentoo
make oldconfig       # pyta interaktywnie tylko o NOWE opcje
# albo:
make olddefconfig    # jak wyżej, ale bierze wartości domyślne zamiast pytać
```

Cała ręczna praca (wyłączone WiFi, karty sieciowe, wybrane Btrfs/USB HID itd.) zostaje
zachowana — to jest właściwy sens zrobienia tego raz porządnie.

**Backup `.config`** — konwencja: `cp .config /boot/config-$(make kernelrelease)` obok samego
kernela, żeby zawsze wiedzieć dokładnie jaki config wyprodukował dany działający kernel.

**`CONFIG_LOCALVERSION`** — dopisuje własny "podpis" do wersji (widoczny w `uname -r`),
przydatne przy eksperymentowaniu z kilkoma configami naraz.

**`.config` to zwykły plik tekstowy** (`CONFIG_FOO=y` per linia) — można go `grep`ować albo
edytować ręcznie, `menuconfig` to tylko wygodna nakładka.

**Alternatywne frontendy** dla tego samego `.config`: `make nconfig` (nowszy ncurses UI),
`make xconfig` (graficzny, Qt).

**Po boocie: `dmesg`** — główne narzędzie diagnostyczne, żeby sprawdzić czy dany sterownik
faktycznie podpiął się pod urządzenie (np. czy Virtio GPU/dysk się wykryły poprawnie).

Zobacz też: [[notes/05-future-ideas.md]] (rzeczy świadomie odłożone), `notes/04-kernel-config.md`
(konkretne decyzje z tej instalacji).
