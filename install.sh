#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Cargar config ─────────────────────────────────────────────────────────────
. "${SCRIPT_DIR}/config.sh"

# ── Perfil ────────────────────────────────────────────────────────────────────
PROFILE="${1:-gnome}"
PROFILE_FILE="${SCRIPT_DIR}/profiles/${PROFILE}.sh"

if [ ! -f "$PROFILE_FILE" ]; then
    echo "Error: perfil '${PROFILE}' no encontrado en profiles/"
    echo "Perfiles disponibles: minimal, gnome, server"
    exit 1
fi

. "$PROFILE_FILE"

# ── Módulo 01: disco ──────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════"
echo "  MÓDULO 01 — Preparación de disco"
echo "════════════════════════════════════════════════════════════════"
bash "${SCRIPT_DIR}/modules/01-disk.sh"

# Cargar variables exportadas por el módulo de disco
. "${SCRIPT_DIR}/partition.info"

# ── Montar sistema de archivos ────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════"
echo "  Montando sistema de archivos"
echo "════════════════════════════════════════════════════════════════"

mkdir -p "$TARGET"
mount "${ROOT_PART}" "$TARGET"

if [ "$FIRMWARE" = "UEFI" ] && [ -n "$EFI_PART" ]; then
    mkdir -p "${TARGET}/boot/efi"
    mount "$EFI_PART" "${TARGET}/boot/efi"
fi

echo "  ✓  Montado en $TARGET"
echo ""

# ── Módulo 02: mmdebstrap ─────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════"
echo "  MÓDULO 02 — Instalación base (mmdebstrap)"
echo "  Suite   : ${SUITE}"
echo "  Perfil  : ${PROFILE}"
echo "  Target  : ${TARGET}"
echo "════════════════════════════════════════════════════════════════"
echo ""

export LOCALE TIMEZONE HOSTNAME KEYMAP

mmdebstrap \
    --variant=apt \
    --components="${COMPONENTS}" \
    --aptopt='APT::Install-Recommends "0"' \
    --aptopt='APT::Install-Suggests "0"' \
    --aptopt='DPkg::Options { "--force-confdef"; "--force-confold"; }' \
    --hook-directory="${HOOK_DIR}" \
    --include="${PACKAGES}" \
    "${SUITE}" \
    "${TARGET}" \
    "${MIRROR}"

# ── Módulo 03: fstab ──────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  MÓDULO 03 — Generando fstab"
echo "════════════════════════════════════════════════════════════════"

ROOT_UUID=$(blkid -s UUID -o value "${ROOT_PART}")
EFI_UUID=""
[ -n "$EFI_PART" ] && EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")

{
    echo "# <file system>  <mount point>  <type>  <options>          <dump>  <pass>"
    echo "UUID=${ROOT_UUID}  /              ext4    errors=remount-ro  0       1"
    [ -n "$EFI_UUID" ] && \
    echo "UUID=${EFI_UUID}   /boot/efi      vfat    umask=0077         0       1"
} > "${TARGET}/etc/fstab"

echo "  ✓  fstab generado"
cat "${TARGET}/etc/fstab" | sed 's/^/    /'
echo ""

# ── Módulo 04: GRUB ───────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════"
echo "  MÓDULO 04 — Instalando GRUB"
echo "════════════════════════════════════════════════════════════════"

for fs in dev proc sys; do
    mount --bind "/$fs" "${TARGET}/$fs"
done
[ -d /sys/firmware/efi ] && mount --bind /sys/firmware/efi/efivars "${TARGET}/sys/firmware/efi/efivars" 2>/dev/null || true

if [ "$FIRMWARE" = "UEFI" ]; then
    chroot "$TARGET" grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot/efi \
        --bootloader-id=Ubuntu \
        --recheck
else
    chroot "$TARGET" grub-install \
        --target=i386-pc \
        "$TARGET_DISK"
fi

chroot "$TARGET" update-grub
echo "  ✓  GRUB instalado"

# ── Desmontar ─────────────────────────────────────────────────────────────────
[ -d /sys/firmware/efi ] && umount "${TARGET}/sys/firmware/efi/efivars" 2>/dev/null || true
for fs in sys proc dev; do
    umount "$TARGET/$fs" 2>/dev/null || true
done
[ -n "$EFI_PART" ] && umount "${TARGET}/boot/efi" 2>/dev/null || true
umount "$TARGET" 2>/dev/null || true

echo
 echo "════════════════════════════════════════════════════════════════"
echo "✓  INSTALACIÓN COMPLETADA"
echo "════════════════════════════════════════════════════════════════"
echo
 echo "  Reinicia el sistema y retira el medio de instalación."
echo
