#!/usr/bin/env bash
# Uruchamiać z Gentoo minimal install ISO (live environment), jako root.
# Partycjonuje dysk, pobiera + weryfikuje + rozpakowuje stage3-amd64-systemd,
# i przygotowuje chroot. Kompilacja świata / kernel config to kolejne, ręczne kroki.

set -euo pipefail

# --- Konfiguracja: dostosuj przed uruchomieniem ---
DISK="/dev/sda"              # docelowy dysk (VirtIO SCSI -> zwykle /dev/sda)
MNT="/mnt/gentoo"
ESP_SIZE="512MiB"
SWAP_SIZE="2GiB"
ROOT_LABEL="rootfs"
BTRFS_MOUNT_OPTS="compress=zstd"
STAGE3_VARIANT="stage3-amd64-systemd"
MIRROR="https://distfiles.gentoo.org/releases/amd64/autobuilds"
WORKDIR="/root/stage3"
# ---------------------------------------------------

require_root() {
    [[ $EUID -eq 0 ]] || { echo "Uruchom jako root." >&2; exit 1; }
}

confirm_wipe() {
    echo "UWAGA: to wyczyści cały dysk ${DISK} i utworzy nowe partycje (GPT)."
    lsblk "${DISK}"
    read -rp "Wpisz dokładnie 'TAK' aby kontynuować: " ans
    [[ "${ans}" == "TAK" ]] || { echo "Przerwano."; exit 1; }
}

partition_disk() {
    echo "==> Partycjonowanie ${DISK} (GPT: ESP / swap / root)"
    sgdisk --zap-all "${DISK}"
    sgdisk -n1:0:+"${ESP_SIZE}"  -t1:ef00 -c1:"EFI System" "${DISK}"
    sgdisk -n2:0:+"${SWAP_SIZE}" -t2:8200 -c2:"swap"        "${DISK}"
    sgdisk -n3:0:0               -t3:8300 -c3:"root"        "${DISK}"
    partprobe "${DISK}"
}

format_partitions() {
    local p1="${DISK}1" p2="${DISK}2" p3="${DISK}3"
    echo "==> Formatowanie partycji"
    mkfs.vfat -F32 "${p1}"
    mkswap "${p2}"
    mkfs.btrfs -f -L "${ROOT_LABEL}" "${p3}"
}

mount_partitions() {
    local p1="${DISK}1" p2="${DISK}2" p3="${DISK}3"
    echo "==> Montowanie do ${MNT}"
    mkdir -p "${MNT}"
    mount -o "${BTRFS_MOUNT_OPTS}" "${p3}" "${MNT}"
    mkdir -p "${MNT}/efi"
    mount "${p1}" "${MNT}/efi"
    swapon "${p2}"
}

fetch_stage3() {
    echo "==> Szukanie najnowszego ${STAGE3_VARIANT}"
    mkdir -p "${WORKDIR}"
    cd "${WORKDIR}"

    local latest_txt="latest-${STAGE3_VARIANT}.txt"
    wget -q "${MIRROR}/${latest_txt}" -O "${latest_txt}"

    local rel_path
    rel_path="$(grep -v '^#' "${latest_txt}" | awk '{print $1}' | head -n1)"
    [[ -n "${rel_path}" ]] || { echo "Nie znaleziono ścieżki do stage3 w ${latest_txt}" >&2; exit 1; }

    local tarball
    tarball="$(basename "${rel_path}")"

    echo "==> Pobieranie ${tarball}"
    wget -q "${MIRROR}/${rel_path}" -O "${tarball}"
    wget -q "${MIRROR}/${rel_path}.asc" -O "${tarball}.asc" || true
    wget -q "${MIRROR}/${rel_path}.sha256" -O "${tarball}.sha256" || true

    if [[ -f "${tarball}.sha256" ]]; then
        echo "==> Weryfikacja sumy kontrolnej"
        sha256sum -c "${tarball}.sha256" --ignore-missing
    else
        echo "Ostrzeżenie: brak pliku .sha256, pomijam weryfikację sumy." >&2
    fi

    echo "${WORKDIR}/${tarball}" > "${WORKDIR}/.tarball_path"
}

extract_stage3() {
    local tarball
    tarball="$(cat "${WORKDIR}/.tarball_path")"
    echo "==> Rozpakowywanie ${tarball} do ${MNT}"
    tar xpvf "${tarball}" --xattrs-include='*.*' --numeric-owner -C "${MNT}"
}

prep_chroot() {
    echo "==> Przygotowanie chroota"
    cp --dereference /etc/resolv.conf "${MNT}/etc/resolv.conf"
    mount --types proc /proc "${MNT}/proc"
    mount --rbind /sys "${MNT}/sys"
    mount --make-rslave "${MNT}/sys"
    mount --rbind /dev "${MNT}/dev"
    mount --make-rslave "${MNT}/dev"
    mount --bind /run "${MNT}/run"
    mount --make-slave "${MNT}/run"
}

print_next_steps() {
    cat <<EOF

==> Gotowe. Dalej ręcznie (zgodnie z Gentoo Handbook):

    chroot ${MNT} /bin/bash
    source /etc/profile
    export PS1="(chroot) \${PS1}"

    # potem: emerge-webrsync, konfiguracja make.conf (CFLAGS -march=native,
    # MAKEOPTS wg liczby vCPU), wybór profilu, kernel, fstab, bootloader (GRUB UEFI).
    #
    # PAMIĘTAJ w kernelu: CONFIG_BTRFS_FS=y (na stałe, nie moduł -- root fs
    # musi być czytelny zanim cokolwiek się zaladuje jako moduł).
    # W fstab dla root: opcja mount "compress=zstd" (tak jak przy ręcznym montowaniu wyżej).

EOF
}

main() {
    require_root
    confirm_wipe
    partition_disk
    format_partitions
    mount_partitions
    fetch_stage3
    extract_stage3
    prep_chroot
    print_next_steps
}

main "$@"
