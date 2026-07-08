# Konfiguracja bazowa Portage — profil i make.conf

Wykonane w chroocie (`arch-chroot /mnt/gentoo`), zgodnie z Gentoo Handbook
("Configuring compile options" + wybór profilu).

## Profil: `default/linux/amd64/23.0/systemd`

**Zmiana decyzji względem `notes/01`:** tam padło założenie `no-multilib` (VM czysto
serwerowa/homelab). W trakcie tego kroku ustaliliśmy, że VM ma docelowo dostać też
środowisko graficzne — więc `no-multilib` odpada, bo blokuje 32-bit libs, które bywają
potrzebne po stronie GUI (Steam, Wine, część proprietary driverów).

Wybrany profil to zwykły `default/linux/amd64/23.0/systemd` (bez `no-multilib`, bez
presetu `desktop`/`desktop/gnome`/`desktop/plasma`) — **świadomie bez presetu desktopowego**,
mimo planów na GUI: cel projektu to nauka "od zera", więc X11/DE i związane z nimi USE
flags dodamy ręcznie, kiedy przyjdzie na to czas, zamiast pozwolić profilowi zdecydować
za nas. Profil był już aktywny domyślnie po rozpakowaniu stage3-amd64-systemd — nie
trzeba było używać `eselect profile set`.

Odrzucone warianty: `hardened` (dodatkowe tarcie przy GUI/proprietary softcie, niepotrzebne
na start), `desktop`/`desktop/gnome`/`desktop/plasma` (mniej nauki — profil sam dobiera
USE flagi pod DE zamiast robić to świadomie).

## `/etc/portage/make.conf`

```
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

RUSTFLAGS="-C target-cpu=native"

MAKEOPTS="-j8 -l9"
```

**`-march=native`** — ma sens wyłącznie dzięki CPU type `host` ustawionemu w Proxmoksie
(`notes/01`), który przepuszcza pełny zestaw flag fizycznego CPU do gościa.

**`-O2`, `-pipe`** — zostawione ze stage3 defaults, zgodnie z zaleceniem wiki (`-O3` psuje
rzeczy systemowo, `-pipe` bez wpływu na wygenerowany kod, tylko więcej RAM-u — akceptowalne
przy 12 GiB).

**`RUSTFLAGS="-C target-cpu=native"`** — spójne z `-march=native` dla C/C++, zero kosztu
dopisać teraz mimo że Rust jeszcze nie jest zainstalowany na stage3.

**`MAKEOPTS="-j8 -l9"`** — świadomie **pełne 8 wątków**, nie `min(wątki, RAM/2GiB)=6` jak
sugeruje wiki (12 GiB / 8 jobs = 1.5 GiB/job, poniżej zalecanych 2 GiB/job). Zaakceptowane
ryzyko OOM przy cięższych pakietach — fallback: zmniejszyć `-j` albo dodać RAM w Proxmoksie
(patrz `notes/01`, sekcja Memory tab).

## Mirrory i news

- `emerge --ask app-portage/mirrorselect` → `mirrorselect -i -o >> /etc/portage/make.conf`
  — wybór szybszych mirrorów zamiast pojedynczego `distfiles.gentoo.org`.
- Po pierwszym `emerge-webrsync`: 16 news items do przeczytania (`eselect news list` /
  `eselect news read`) — mogą zawierać istotne informacje wymagające ręcznej akcji przed
  dalszymi krokami.

## Do zapamiętania na później (GUI)

Skoro no-multilib odpadło z myślą o GUI: przy konfiguracji kernela i USE flags pod X11/DE
pamiętać o `ABI_X86="64 32"` (multilib) tam, gdzie będzie to potrzebne (np. sterowniki GPU).
