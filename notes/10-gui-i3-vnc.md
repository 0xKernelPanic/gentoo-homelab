# GUI: i3 + zdalny dostęp przez VNC — decyzje i pułapki

## Wybór DE/WM i sposobu dostępu

- **X11, nie Wayland** — świadomie, bo nie mamy skonfigurowanej akceleracji 3D dla Virtio GPU;
  większość Wayland compositorów wymaga działającego OpenGL/EGL nawet do podstawowego
  działania, X11 (stacking/tiling WM) może działać na czystym software renderingu.
- **i3** (tiling WM), nie pełny DE (GNOME/KDE) — mniej "magii", maksimum nauki o tym jak się
  składa WM + pasek (i3bar) + launcher (dmenu) + terminal (xterm) z osobnych klocków.
- **Dostęp: zdalny (VNC), nie lokalna konsola Proxmoksa** — zmiana pierwotnej decyzji (patrz
  niżej, sekcja o Virtio GPU) po napotkaniu nierozwiązanego problemu z lokalnym ekranem.

## Nierozwiązany problem: lokalna konsola Proxmoksa (Virtio GPU/DRM)

System **w pełni działa** (potwierdzone przez serial console, `notes/08`), ale konsola
graficzna Proxmoksa (VNC/SPICE) pokazuje pusty ekran po `Loading Linux ...`. Diagnoza z
działającego systemu:

- `dmesg`: sterownik `virtio_gpu` ładuje się **poprawnie**, `/dev/dri/card0` i `renderD128`
  istnieją, zero błędów.
- `cat /sys/class/drm/card0-Virtual-1/status` → **`unknown`** (nie `connected`).
- `cat /sys/class/drm/card0-Virtual-1/modes` → **pusty** — DRM nie wynegocjował **żadnego**
  trybu wyświetlania.
- Wymuszenie trybu przez kernel cmdline (`video=Virtual-1:1024x768-32`) — **nie pomogło**.
- `nomodeset` jako test — też nic nie pokazał, ale to zawodny test na czystym UEFI (brak
  awaryjnego trybu tekstowego VGA bez CSM/legacy BIOS).

**Wniosek:** wygląda na problem z negocjacją EDID między gościem (`virtio_gpu`) a hostem
(QEMU/OVMF), niezależny od naszej konfiguracji kernela — znany typ problemu przy `virtio-gpu`
+ `noVNC` (zamiast SPICE). Nie blokujące (mamy SSH), odłożone na później.

## Ślepy zaułek: `tigervnc` + `Xvnc`

Plan A: `net-misc/tigervnc` (`Xvnc` — własny, samodzielny serwer X, nie wymaga DRM/GPU w ogóle,
więc **omija** powyższy problem). Zainstalowany razem z `x11-wm/i3`, `x11-misc/i3status`,
`x11-misc/dmenu`, `x11-terms/xterm`.

**Pułapka 1 — lokalizacja configu:** nowsza wersja `tigervnc` przeszła na konwencję XDG:
`~/.config/tigervnc/` zamiast starego `~/.vnc/`.

**Pułapka 2 — autounmask trafił w przypadkowy plik:** instalacja wymagała USE flag `X` dla
`cairo`/`libxkbcommon`/`pango`, `harfbuzz` dla `freetype`, `X` dla `libglvnd` (zależności
`i3`/`tigervnc[opengl]`) — `autounmask` dopisał je do istniejącego `package.use/sudo` zamiast
nowego pliku (Portage nie ma "inteligentnej" segregacji, nazwa pliku to czysto ludzka etykieta).
Rozdzielone ręcznie na `package.use/sudo` + `package.use/gui-stack`.

**Pułapka 3 (blokująca, nierozwiązana z tigervnc) — `xinit`/VT crash:** `vncserver`/
`vncserver@:1.service` **nie używał** naszego `xstartup` — nowsza wersja `tigervnc`
auto-wykrywa sesje z `/usr/share/xsessions/*.desktop` (jak menedżer logowania) i uruchamia
wybraną sesję przez mechanizm oparty o `xinit`. Ten `xinit` sprawdza właściwość root window
`XFree86_VT` (normalnie ustawianą przez prawdziwy Xorg działający na fizycznym VT) —
**`Xvnc` (headless, bez VT) jej nie ma**, więc `xinit` uznaje że coś jest nie tak i przerywa
sesję (`connection to X server lost`) **natychmiast** po starcie, niezależnie od wybranej
sesji (`i3` i `i3-with-shmlog` — ten sam błąd dla obu). Wygląda na realny bug/niedopasowanie
w tej wersji `tigervnc`, nie błąd konfiguracji z naszej strony.

Przy okazji: log `Xvnc` pokazywał też `virtio_gpu: driver missing` — osobny, prawdziwy
(ale niezwiązany z powyższym crashem) problem: `tigervnc` zbudowany z USE `opengl` szuka
sterownika Mesa dla akceleracji 3D przez `virtio_gpu`, którego nie mieliśmy (profil ma
domyślne `VIDEO_CARDS` bez `virgl` — dokładnie ta odłożona decyzja z `notes/03`). Naprawione
niezależnie:
```bash
echo 'VIDEO_CARDS="virgl"' | sudo tee -a /etc/portage/make.conf
sudo emerge --ask --changed-use media-libs/mesa
```
(Xvnc kontynuował działanie mimo tego komunikatu — to nie była przyczyna crasha z `xinit`.)

## Rozwiązanie: `Xvfb` + `x11vnc`

Zamiast dalej walczyć z nieprzejrzystym mechanizmem sesji `tigervnc`, przejście na prostszą,
w pełni ręczną kombinację:

- **`Xvfb`** (`x11-base/xorg-server[xvfb]`) — czysty wirtualny framebuffer X server, zero
  logiki sesji/VT.
- **`x11-misc/x11vnc`** — **nie jest** własnym serwerem X (w przeciwieństwie do `Xvnc`) —
  podłącza się do **już działającego** X displaya i współdzieli go przez VNC.

### Bezpieczeństwo: `x11vnc` tylko na `localhost` + tunel SSH

`x11vnc` domyślnie wysyła ruch VNC **nieszyfrowany**. Zamiast wystawiać port 5900 na całą
sieć domową, `x11vnc -localhost` nasłuchuje wyłącznie na `127.0.0.1` — dostęp tylko przez
tunel SSH (który i tak już mamy, kluczem, nie hasłem):
```bash
ssh -L 5900:localhost:5900 -i ~/.ssh/gentoo-homelab daniel@<IP> -N
```
potem `vncviewer localhost:5900` w drugim oknie.

### Skrypt + usługa systemd

`/usr/local/bin/start-gui-vnc.sh`:
```bash
#!/bin/sh
set -e
Xvfb :1 -screen 0 1920x1080x24 &
sleep 1
export DISPLAY=:1
i3 &
exec x11vnc -display :1 -forever -shared -rfbauth /home/daniel/.vnc/passwd -localhost -noxdamage
```

`/etc/systemd/system/vnc-i3.service`:
```ini
[Unit]
Description=i3 desktop over VNC (localhost only, dostęp przez tunel SSH)
After=network.target

[Service]
Type=simple
User=daniel
Environment=HOME=/home/daniel
ExecStart=/usr/local/bin/start-gui-vnc.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vnc-i3.service
```

Weryfikacja: `ss -tlnp | grep 5900` musi pokazywać `127.0.0.1:5900`, nie `0.0.0.0:5900`.

## i3 — pierwsze uruchomienie

Przy pierwszym starcie bez istniejącego configu, `i3-config-wizard` pyta o wygenerowanie
domyślnego configu (`~/.config/i3/config`, zwykły plik tekstowy) i klawisz Mod — wybrany
**Super/Win** (nie Alt, zajęty przez inne aplikacje/terminale).

Ostrzeżenia `xss-lock`/`nm-applet`/`dex: command not found` przy starcie i3 są nieszkodliwe —
domyślne wpisy autostart w wygenerowanym configu, dla narzędzi których nie zainstalowaliśmy
(blokada ekranu, applet sieciowy, launcher desktopowy) — do dodania później jeśli potrzebne.

### Podstawowe skróty i3 (Mod = Super)

| Skrót | Akcja |
|---|---|
| `Mod+Enter` | nowy terminal (`xterm`) |
| `Mod+d` | `dmenu` (launcher aplikacji) |
| `Mod+Shift+q` | zamknij okno |
| `Mod+strzałki` / `Mod+hjkl` | przełączanie fokusa |
| `Mod+Shift+strzałki` | przesuwanie okna |
| `Mod+1..9` | przełączanie workspace |
| `Mod+Shift+e` | wyjście z i3 |
