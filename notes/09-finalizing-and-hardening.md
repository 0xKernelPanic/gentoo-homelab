# Finalizing: narzędzia systemowe, sudo, użytkownik, hardening SSH

Odpowiednik `scripts/finalize-system.sh` (część automatyczna) + kroki ręczne poniżej.
Wykonane na już zabootowanym systemie przez SSH (nie w chroocie).

## System logger — pominięty

`systemd-journald` (wbudowany) w zupełności wystarcza — Handbook wprost zaleca pominięcie
dodatkowego syslog na systemd, chyba że potrzebujesz przekazywania logów na centralny host
(nie nasz przypadek).

## Cron — pominięty, ale `fstrim.timer` włączony

Systemd ma własne timery, zamiast osobnego demona cron (spójne z resztą decyzji o
nie-mieszaniu paradygmatów, tak jak przy `systemd-networkd` vs `NetworkManager`). Jedyna
konkretna rzecz z listy "TODO" w `notes/01` (Disks tab: Discard zaznaczone → wymaga fstrim):

```bash
systemctl enable --now fstrim.timer
```

## Narzędzia systemowe

```bash
emerge --ask sys-apps/mlocate app-shells/bash-completion sys-fs/btrfs-progs \
    sys-fs/dosfstools sys-block/io-scheduler-udev-rules app-portage/gentoolkit
```

- `btrfs-progs`/`dosfstools` — narzędzia do naszych filesystemów (Btrfs root, VFAT ESP).
  Uwaga: `btrfs-progs` ma domyślnie włączone USE `zstd` — spójne z `compress=zstd` z `notes/02`.
- `gentoolkit` — `equery uses`/`equery depends`, `eclean-dist`/`eclean-pkg` (czyszczenie starych
  distfiles/binpkgs, patrz sekcja "Portage maintenance" w Handbooku).
- `mlocate`, `bash-completion` — wygoda, brak istotnych USE flags do decyzji.

## sudo zamiast samego `su`

**Dlaczego nie tylko `su -`:** `su -` wymaga hasła **roota**. Jeśli docelowo blokujesz hasło
roota (`passwd -l root`, sekcja niżej) — `su -` przestaje działać **w ogóle**, bo nie ma czym
się zalogować. `sudo` autoryzuje własnym hasłem użytkownika, więc dalej działa po zablokowaniu
roota. To jest dokładnie powód, dla którego Handbook ostrzega: skonfiguruj `sudo`/`doas`
**przed** zablokowaniem roota, nie po.

### USE flags: `offensive` włączone, `sendmail` wyłączone

```bash
mkdir -p /etc/portage/package.use
echo "app-admin/sudo offensive -sendmail" > /etc/portage/package.use/sudo
emerge --ask app-admin/sudo
```

- **`offensive`** — sudo wypisuje żartobliwe wyzwiska przy złym haśle zamiast zwykłego
  komunikatu (prawdziwa, historyczna funkcja `sudo`, inspirowana starą grą z lat 80.). Zero
  wpływu na bezpieczeństwo, czysta zabawa.
- **`-sendmail`** — brak serwera pocztowego w homelabie, powiadomienia mailem o nieudanych
  próbach `sudo` są bezużyteczne.
- **`secure-path`** (domyślnie włączone, nie zmienialiśmy) — realna ochrona: `sudo` ignoruje
  `PATH` użytkownika i używa stałej, bezpiecznej listy katalogów wkompilowanej w program,
  zapobiegając podstawieniu złośliwego binarnego pliku przez manipulację `PATH`.

**Ciekawostka o `equery uses` dla niezainstalowanego pakietu:** kolumny `U`/`I` mogą się różnić
przed instalacją (`U` = finalna wartość po zastosowaniu profilu/`package.use`, `I` prawdopodobnie
domyślna wartość z samego ebuilda) — po instalacji obie kolumny się zrównują, potwierdzone
empirycznie na `secure-path`/`sendmail`.

```bash
visudo
```
Odkomentować:
```
%wheel ALL=(ALL:ALL) ALL
```

`scripts/finalize-system.sh` robi to inaczej: zamiast edytować `/etc/sudoers` wkłada tę linię do
osobnego pliku `/etc/sudoers.d/wheel`, sprawdzonego wcześniej przez `visudo -cf`. Błąd składni w
`sudoers` blokuje `sudo` całkowicie, a przy zablokowanym roocie nie byłoby już jak go naprawić.

## Zwykły użytkownik

```bash
useradd -m -G users,wheel,audio,video -s /bin/bash daniel
passwd daniel
```

Grupy: `wheel` (sudo), `users`/`audio`/`video` (standard + przyszłe GUI, zero kosztu dodać teraz).

**Pułapka:** `useradd` tworzy konto **bez ważnego hasła** (zablokowane) dopóki nie odpalisz
`passwd` osobno — dokładnie ten sam problem co z rootem na starcie (`notes/08`). Bez tego
`sudo`/logowanie nie zadziała, mimo poprawnie wpisanego "hasła".

## Pułapka: `pam_faillock` blokuje konto po 3 błędnych próbach

Po kilku nieudanych próbach hasła przy `sudo` (np. pomyłkowo wpisane hasło roota zamiast
`daniel`), PAM **tymczasowo blokuje konto** (`pam_faillock`, ochrona przed brute-force —
używana domyślnie też np. w RHEL/Fedora, nie jest to niszowa/gentoo-specyficzna rzecz).

Diagnoza i reset:
```bash
faillock --user daniel
faillock --user daniel --reset
```

## Klucz SSH + blokada roota (ręcznie, w tej kolejności)

1. Klucz publiczny (`~/.ssh/id_ed25519.pub` z maszyny klienckiej) → `/home/daniel/.ssh/authorized_keys`
   na VM (uprawnienia: katalog `700`, plik `600`, właściciel `daniel:daniel`).
2. **Zweryfikuj** logowanie kluczem + `sudo` z zewnątrz, zanim pójdziesz dalej.
3. Dopiero wtedy:
   ```bash
   passwd -l root
   # /etc/ssh/sshd_config: PermitRootLogin no
   systemctl restart sshd
   ```

Przypomnienie z Handbooka (dokładnie ta pułapka, w którą wcześniej wpadliśmy przy pierwszej
próbie SSH — `notes/08`): domyślne `PermitRootLogin prohibit-password` i tak nie pozwala
rootowi logować się hasłem, tylko kluczem — `PermitRootLogin no` idzie o krok dalej i
blokuje roota przez SSH całkowicie, niezależnie od metody.

## Do zrobienia dalej

- `qemu-guest-agent` (zaplanowane w Proxmoksie od samego początku, `notes/01`)
- `eclean-dist`/`eclean-pkg` — sprzątanie starych distfiles/binpkgs (opcjonalne, `gentoolkit` już mamy)
- Zbadanie problemu z ekranem graficznym (Virtio GPU/DRM) — kosmetyczne, nieblokujące (`notes/08`)
