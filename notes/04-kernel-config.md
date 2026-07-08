# Kernel — decyzje i dlaczego

Zgodnie z README ("Kernel — ręczna konfiguracja"): ścieżka **manualna** (`sys-kernel/gentoo-sources`
+ ręczny `make menuconfig`), nie distribution kernel (`gentoo-kernel`/`gentoo-kernel-bin`).

## Decyzje ogólne (przed menuconfig)

| Decyzja | Wybór | Dlaczego |
|---|---|---|
| Bootloader | **GRUB** | Najbardziej uniwersalna, najszerzej udokumentowana wiedza (przenosi się na inne dystrybucje). Klasyczny wybór "if unsure" z Handbooka. |
| `sys-kernel/installkernel` | **Bez niego, w pełni ręcznie** | Sam `make install` + ręczny `grub-install`/`grub-mkconfig` później — uczymy się całego pipeline'u boot zamiast pozwolić narzędziu go ukryć. Spójne z resztą projektu (ręczne partycjonowanie, ręczny make.conf). |
| Initramfs | **Brak** — kernel monolityczny | Wszystko potrzebne do zamontowania roota (VirtIO SCSI, BTRFS) wbudowane na stałe (`=y`), więc initramfs (rozwiązujący problem "moduł nie może się załadować z niezamontowanego roota") jest zbędny. Jeśli w przyszłości dojdzie LUKS na **root**, initramfs stanie się konieczny — do zrobienia wtedy, nie na zapas (LUKS na dodatkowym wolumenie danych, nie-root, w ogóle by initramfs nie wymagał — odszyfrowanie przez `/etc/crypttab` już po starcie). |
| Punkt startowy configu | **`make defconfig` + ręczne dostrajanie w `menuconfig`** | Odrzucone: `make allnoconfig` (dosłownie od zera — zbyt czasochłonne, malejąca wartość edukacyjna po pierwszych kilkudziesięciu opcjach) i `make localmodconfig` (Option 2 z Handbooka — auto-dopasowanie do modułów załadowanych przez *live ISO*, mniej zrozumienia, więcej "zgadywania za nas"). |
| Zakres "sprzątania" defconfig | **Średni** — hurtowe wyłączanie dużych, oczywiście zbędnych kategorii, bez przeglądania pojedynczo tysięcy opcji | Pozostawienie defconfig praktycznie nietkniętym byłoby równoznaczne z użyciem distribution kernela (ten sam szeroki, generyczny config) — mijałoby się z celem ręcznej konfiguracji. Przegląd opcja-po-opcji dla całego drzewa Kconfig ma malejącą wartość edukacyjną i realnie zajmuje wiele godzin. |

## Realny sprzęt VM (z `lspci` / `lspci -k`, live ISO)

| Urządzenie | CONFIG_* | Uwagi |
|---|---|---|
| `SCSI storage controller: Virtio SCSI` | `SCSI_VIRTIO=y` (+ `SCSI=y`, `BLK_DEV_SD=y`) | **Poprawka względem `notes/01`/`notes/02`**: zakładaliśmy że potrzebne będzie i `VIRTIO_BLK`, i `VIRTIO_SCSI`. Realnie w `lspci` jest **tylko** Virtio SCSI (bo w Proxmoksie wybrany kontroler to "VirtIO SCSI single", nie "VirtIO Block") — `VIRTIO_BLK` jest zbędny. |
| `Ethernet controller: Virtio network device` | `VIRTIO_NET=y` | Już `=y` domyślnie z defconfig. |
| `Communication controller: Virtio console` ×2 | `VIRTIO_CONSOLE=y` | Kanał używany przez `qemu-guest-agent`. Już `=y` domyślnie. |
| `VGA compatible controller: Virtio 1.0 GPU` | `DRM_VIRTIO_GPU` | **Do sprawdzenia/ustawienia** — bez tego brak obrazu na konsoli Proxmoksa (i brak możliwości debugowania bootu przed uruchomieniem SSH). |
| USB UHCI/EHCI controllers (ICH9) | `USB_UHCI_HCD`, `USB_EHCI_HCD`, `USB_HID` | Przez te kontrolery działa wirtualna klawiatura/mysz w konsoli noVNC/SPICE Proxmoksa — bez `USB_HID` brak inputu w konsoli (np. przy awarii przed działającym SSH). **Do sprawdzenia/ustawienia.** |
| SATA AHCI (ICH9), HD Audio (ICH9), SMBus (ICH9) | — | Obecne w `lspci`, ale nieużywane (brak podłączonego dysku SATA, brak potrzeby audio/SMBus na serwerze) — pominięte, niski priorytet. |

**Model dwuwarstwowy VirtIO**: `lspci -k` pokazuje `Kernel driver in use: virtio-pci` dla *wszystkich* urządzeń Virtio — to tylko warstwa transportu PCI. Właściwy sterownik funkcjonalny (`virtio_scsi`, `virtio_net`, `virtio_gpu`, `virtio_console`) żyje na osobnej, wewnętrznej magistrali virtio, niewidocznej w `lspci`. Dlatego identyfikacja CONFIG_* poszła po **typie urządzenia** (nazwa w `lspci`), nie po kolumnie "Kernel driver in use".

**Kwirk nazewnictwa Kconfig**: sterownik virtio dla SCSI nazywa się `SCSI_VIRTIO`, nie `VIRTIO_SCSI` — bo leży pod "SCSI device support" jako jeden z wielu `SCSI_<coś>` sterowników niskopoziomowych, nie pod rodziną `VIRTIO_*`.

## Wyłączone kategorie (hurtowo, w `menuconfig`)

Device Drivers (top-level): PCCard/PCMCIA, NVMe, Multiple devices driver support (RAID **and LVM/Device Mapper** — w tym przyszły `dm-crypt`/LUKS, świadomie odłożone), IEEE 1394 (FireWire), Macintosh device drivers.

Network device support: USB Network Adapters, Wireless LAN (cały stos WiFi/`cfg80211`/`mac80211`).

Ethernet driver support: wszystkie konkretne sterowniki producentów mimo że kategorie-nagłówki (np. `[*] Intel devices`) zostały zaznaczone — to tylko przełączniki widoczności podmenu, nie kompilują kodu same z siebie. Realnie wyłączone: Broadcom Tigon3, Intel PRO/100+, Intel PRO/1000, Intel PRO/1000 PCI-E (e1000/e1000e), sprawdzony też Realtek r8169.

Input device support: Joysticks/Gamepads, Tablets, Touchscreens. Zachowane: `evdev` (Event interface, fundament pod przyszłe X/Wayland), Keyboards/Mice (domyślne, do zweryfikowania razem z USB support).

Character devices: **`Allow legacy TIOCSTI usage` (`CONFIG_LEGACY_TIOCSTI`) — świadomie wyłączone**, mimo wyboru profilu nie-hardened. TIOCSTI pozwala procesowi wstrzykiwać znaki do cudzego terminala (historyczny wektor eskalacji uprawnień/ucieczki z kontenerów) — dodane do mainline kernela dopiero w 6.2 (2023) jako opcja wyłączalna bez potrzeby patchy hardened. Zero realnego kosztu funkcjonalnego dla tego use case (jednoosobowy homelab, brak zależności od `reptyr`/starych skryptów `expect`) — "darmowy" hardening.

**Potwierdzone spójne z wcześniejszymi decyzjami**: `TPM Hardware Support` wyłączone w kernelu, zgodnie z odznaczonym "Add TPM" w Proxmoksie (`notes/01`).

## Do zrobienia dalej

- `Graphics support` → `DRM_VIRTIO_GPU`
- `USB support` → `USB_HID` + `UHCI_HCD`/`EHCI_HCD`
- `File systems` → potwierdzić `BTRFS_FS=y` (wbudowane, nie moduł)
- Kompilacja: `make -j8 && make modules_install && make install` (bez `installkernel`)
- Ręczna instalacja GRUB: `grub-install` + `grub-mkconfig`
