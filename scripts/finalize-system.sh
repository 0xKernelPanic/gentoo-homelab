#!/usr/bin/env bash
# Uruchamiać na już zabootowanym, zainstalowanym systemie (NIE w chroocie), jako root.
# Konfiguruje narzędzia systemowe, sudo (z przemyślanymi USE flags), zwykłego użytkownika
# i fstrim. Kroki wymagające sekretów (hasła, klucz SSH, blokada roota) są ręczne —
# patrz print_next_steps() na końcu, oraz notes/09-finalizing-and-hardening.md.

set -euo pipefail

# --- Konfiguracja: dostosuj przed uruchomieniem ---
USERNAME="daniel"
USER_GROUPS="users,wheel,audio,video"
USER_SHELL="/bin/bash"
# ---------------------------------------------------

require_root() {
    [[ $EUID -eq 0 ]] || { echo "Uruchom jako root (albo przez sudo)." >&2; exit 1; }
}

install_system_tools() {
    echo "==> Narzędzia systemowe (mlocate, bash-completion, btrfs-progs, dosfstools, io-scheduler-udev-rules, gentoolkit)"
    emerge --ask sys-apps/mlocate app-shells/bash-completion sys-fs/btrfs-progs \
        sys-fs/dosfstools sys-block/io-scheduler-udev-rules app-portage/gentoolkit
}

configure_sudo_use_flags() {
    echo "==> USE flags dla sudo: offensive (żarty przy złym haśle), bez sendmail (brak serwera pocztowego)"
    mkdir -p /etc/portage/package.use
    echo "app-admin/sudo offensive -sendmail" > /etc/portage/package.use/sudo
}

install_sudo() {
    echo "==> Instalacja sudo"
    emerge --ask app-admin/sudo
}

configure_sudoers() {
    # Osobny plik w /etc/sudoers.d zamiast edycji /etc/sudoers przez sed: błąd składni
    # w sudoers blokuje sudo całkowicie, więc plik jest najpierw sprawdzany przez visudo,
    # a dopiero potem instalowany z właściwymi uprawnieniami.
    echo "==> Grupa wheel w /etc/sudoers.d/wheel"
    local tmp
    tmp="$(mktemp)"
    echo "%wheel ALL=(ALL:ALL) ALL" > "${tmp}"
    visudo -cf "${tmp}"
    install -m 0440 -o root -g root "${tmp}" /etc/sudoers.d/wheel
    rm -f "${tmp}"
}

create_user() {
    if id "${USERNAME}" &>/dev/null; then
        echo "==> Użytkownik ${USERNAME} już istnieje, pomijam useradd"
    else
        echo "==> Tworzenie użytkownika ${USERNAME} (grupy: ${USER_GROUPS})"
        useradd -m -G "${USER_GROUPS}" -s "${USER_SHELL}" "${USERNAME}"
    fi
    echo "==> Ustaw hasło dla ${USERNAME}:"
    passwd "${USERNAME}"
}

enable_fstrim() {
    echo "==> Włączanie fstrim.timer (TRIM dla thin-provisioned storage, patrz notes/01 Disks tab)"
    systemctl enable --now fstrim.timer
}

print_next_steps() {
    cat <<EOF

==> Gotowe automatycznie. Zostały kroki RĘCZNE, wymagające sekretów —
    rób je w tej kolejności, i zweryfikuj każdy krok zanim przejdziesz dalej:

    1. Dodaj klucz SSH dla ${USERNAME} (klucz PUBLICZNY z Twojej maszyny, ~/.ssh/id_ed25519.pub):

       mkdir -p /home/${USERNAME}/.ssh
       chmod 700 /home/${USERNAME}/.ssh
       echo "<WKLEJ TU SWÓJ KLUCZ PUBLICZNY>" >> /home/${USERNAME}/.ssh/authorized_keys
       chmod 600 /home/${USERNAME}/.ssh/authorized_keys
       chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh

    2. Z DRUGIEGO terminala (nie zamykaj obecnej sesji roota!), zweryfikuj że działa:

       ssh ${USERNAME}@<IP>          # powinno zalogować bez hasła (klucz)
       sudo whoami                   # powinno poprosić o hasło ${USERNAME}, zwrócić "root"

    3. Dopiero PO potwierdzeniu że powyższe działa, zablokuj roota:

       passwd -l root
       # w /etc/ssh/sshd_config: PermitRootLogin no
       systemctl restart sshd

    Uwaga: PAM może zablokować konto po kilku błędnych próbach hasła (pam_faillock).
    Odblokowanie: faillock --user ${USERNAME} --reset

EOF
}

main() {
    require_root
    install_system_tools
    configure_sudo_use_flags
    install_sudo
    configure_sudoers
    create_user
    enable_fstrim
    print_next_steps
}

main "$@"
