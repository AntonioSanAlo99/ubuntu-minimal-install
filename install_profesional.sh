#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/config.sh"

# ── Verificaciones previas ────────────────────────────────────────────────────

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: este script debe ejecutarse como root." >&2
    exit 1
fi

chmod +x "${SCRIPT_DIR}/hooks/"*.sh "${SCRIPT_DIR}/modules/"*.sh

# ── Detección de firmware ─────────────────────────────────────────────────────
if [ -d /sys/firmware/efi ]; then
    FIRMWARE="UEFI"
    GRUB_PKG="grub-efi-amd64"
else
    FIRMWARE="BIOS"
    GRUB_PKG="grub-pc"
fi
echo "Firmware: $FIRMWARE  →  $GRUB_PKG"

# ── Dependencias del instalador ───────────────────────────────────────────────
echo ""
echo "Verificando dependencias..."
_missing=""

for _pkg in mmdebstrap ubuntu-keyring parted arch-install-scripts \
            dosfstools e2fsprogs efibootmgr python3 "${GRUB_PKG}"; do
    if ! dpkg -s "$_pkg" &>/dev/null; then
        echo "  falta: $_pkg"
        _missing="1"
    fi
done

if [ -n "$_missing" ]; then
    echo ""
    echo "Instalando las dependencias"
    apt install mmdebstrap ubuntu-keyring parted arch-install-scripts \
    dosfstools e2fsprogs efibootmgr python3  ${GRUB_PKG}
    exit 1
fi
echo "  OK"
echo ""

# ── Utilidades ────────────────────────────────────────────────────────────────

ask() {
    # ask <varname> <prompt> [default]
    local _var="$1" _prompt="$2" _default="$3" _val
    while true; do
        if [ -n "$_default" ]; then
            read -rp "${_prompt} [${_default}]: " _val
            _val="${_val:-$_default}"
        else
            read -rp "${_prompt}: " _val
        fi
        [ -n "$_val" ] && break
        echo "  El campo no puede estar vacío."
    done
    printf -v "$_var" '%s' "$_val"
}

ask_secret() {
    # ask_secret <varname> <prompt>
    local _var="$1" _prompt="$2" _p1 _p2
    while true; do
        read -rsp "${_prompt}: " _p1; echo
        read -rsp "Confirmar contraseña: " _p2; echo
        if [ -z "$_p1" ]; then
            echo "  La contraseña no puede estar vacía."
        elif [ "$_p1" != "$_p2" ]; then
            echo "  Las contraseñas no coinciden."
        else
            printf -v "$_var" '%s' "$_p1"
            return
        fi
    done
}

ask_yn() {
    # ask_yn <varname> <prompt> <default: y|n>
    local _var="$1" _prompt="$2" _default="${3:-n}" _val
    while true; do
        read -rp "${_prompt} (y/n) [${_default}]: " _val
        _val="${_val:-$_default}"
        case "$_val" in
            y|Y) printf -v "$_var" 'yes'; return ;;
            n|N) printf -v "$_var" 'no';  return ;;
            *) echo "  Responde y o n." ;;
        esac
    done
}

hr() { printf '%0.s-' {1..60}; echo; }

# ── Wizard ────────────────────────────────────────────────────────────────────

clear
echo "Ubuntu Minimal Install"
echo "setup-ubuntu v1.0"
hr

# Perfil
echo ""
echo "Perfiles disponibles: gnome, minimal"
ask PROFILE "Perfil de instalación" "${1:-gnome}"
PROFILE_FILE="${SCRIPT_DIR}/profiles/${PROFILE}.sh"
if [ ! -f "$PROFILE_FILE" ]; then
    echo "Error: perfil '${PROFILE}' no encontrado." >&2
    exit 1
fi
. "$PROFILE_FILE"

# Sistema
echo ""
hr
echo "Configuración del sistema"
hr
ask HOSTNAME  "Hostname"              "$HOSTNAME"
ask TIMEZONE  "Zona horaria"          "$TIMEZONE"
ask LOCALE    "Locale"                "$LOCALE"
ask KEYMAP    "Distribución teclado"  "$KEYMAP"

# Usuario
echo ""
hr
echo "Cuenta de usuario"
hr
ask        USERNAME      "Nombre de usuario"    "usuario"
ask_secret USER_PASSWORD "Contraseña"
USER_FULLNAME="$USERNAME"

# Root
echo ""
echo "Acceso root:"
echo "  (y) Con contraseña  — permite 'su -' y login directo como root."
echo "  (n) Sin contraseña  — root solo accesible con 'sudo -i'."
echo "      Recomendado para escritorio."
echo ""
ask_yn _set_root "¿Activar contraseña directa para root?" "n"
if [ "$_set_root" = "yes" ]; then
    ask_secret ROOT_PASSWORD "Contraseña de root"
else
    ROOT_PASSWORD=""
fi

# GDM autologin (sólo si el perfil incluye gdm3)
GDM_AUTOLOGIN="no"
if echo "$PACKAGES" | grep -q "gdm3"; then
    echo ""
    ask_yn GDM_AUTOLOGIN "¿Activar inicio de sesión automático (GDM)?" "n"
fi

# Resumen y confirmación
echo ""
hr
echo "Resumen"
hr
echo "  Perfil         : $PROFILE"
echo "  Hostname       : $HOSTNAME"
echo "  Zona horaria   : $TIMEZONE"
echo "  Locale         : $LOCALE"
echo "  Teclado        : $KEYMAP"
echo "  Usuario        : $USERNAME"
echo "  Root password  : $([ -n "$ROOT_PASSWORD" ] && echo "configurada" || echo "bloqueada")"
echo "  GDM autologin  : $GDM_AUTOLOGIN"
echo ""
echo "AVISO: el disco seleccionado a continuación será borrado."
echo ""
ask_yn _go "¿Continuar?" "n"
[ "$_go" != "yes" ] && echo "Instalación cancelada." && exit 0

export LOCALE TIMEZONE HOSTNAME KEYMAP FIRMWARE
export USERNAME USER_FULLNAME USER_PASSWORD ROOT_PASSWORD GDM_AUTOLOGIN

# ── Módulo 01: disco ──────────────────────────────────────────────────────────
echo ""
hr
echo "Preparación del disco"
hr
bash "${SCRIPT_DIR}/modules/01-disk.sh"
. "${SCRIPT_DIR}/partition.info"

# ── Montar ────────────────────────────────────────────────────────────────────
echo ""
echo "Montando sistema de archivos..."
mkdir -p "$TARGET"
mount "${ROOT_PART}" "$TARGET"
if [ "$FIRMWARE" = "UEFI" ] && [ -n "$EFI_PART" ]; then
    mkdir -p "${TARGET}/boot/efi"
    mount "$EFI_PART" "${TARGET}/boot/efi"
fi
echo "  Montado en $TARGET"

# ── mmdebstrap ────────────────────────────────────────────────────────────────
echo ""
hr
echo "Instalando sistema base (mmdebstrap)"
hr
echo "  Suite   : $SUITE"
echo "  Perfil  : $PROFILE"
echo "  Target  : $TARGET"
echo ""

mmdebstrap \
    --variant=apt \
    --components="${COMPONENTS}" \
    --aptopt='APT::Install-Recommends "0"' \
    --aptopt='APT::Install-Suggests "0"' \
    --dpkgopt='force-confdef' \
    --dpkgopt='force-confold' \
    --hook-directory="${HOOK_DIR}" \
    --include="${PACKAGES}" \
    "${SUITE}" \
    "${TARGET}" \
    "${MIRROR}"

# ── fstab ─────────────────────────────────────────────────────────────────────
echo ""
echo "Generando fstab..."
ROOT_UUID=$(blkid -s UUID -o value "${ROOT_PART}")
EFI_UUID=""
[ -n "$EFI_PART" ] && EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
{
    echo "# <file system>  <mount point>  <type>  <options>          <dump>  <pass>"
    echo "UUID=${ROOT_UUID}  /              ext4    errors=remount-ro  0       1"
    [ -n "$EFI_UUID" ] && \
    echo "UUID=${EFI_UUID}   /boot/efi      vfat    umask=0077         0       1"
} > "${TARGET}/etc/fstab"
echo "  OK"

# ── GRUB ──────────────────────────────────────────────────────────────────────

# ── Configuración de Usuarios y Contraseñas (Nivel Profesional) ──────────────
echo ""
hr
echo "Configurando usuarios y contraseñas..."
hr

# Crear usuario si no existe y añadir a grupos
chroot "$TARGET" id -u "$USERNAME" &>/dev/null || \
    chroot "$TARGET" useradd -m -s /bin/bash -G sudo,adm,cdrom,plugdev,lpadmin,sambashare "$USERNAME"

# Aplicar contraseñas de forma segura (maneja símbolos raros)
printf '%s:%s' "$USERNAME" "$USER_PASSWORD" | chroot "$TARGET" chpasswd

if [ -n "$ROOT_PASSWORD" ]; then
    printf 'root:%s' "$ROOT_PASSWORD" | chroot "$TARGET" chpasswd
else
    chroot "$TARGET" passwd -l root
fi

# Configuración de GDM3 (Autologin)
if [ -d "${TARGET}/etc/gdm3" ]; then
    echo "  Configurando GDM3..."
    cat <<EOF > "${TARGET}/etc/gdm3/custom.conf"
[daemon]
AutomaticLoginEnable=$( [ "$GDM_AUTOLOGIN" = "yes" ] && echo "True" || echo "False" )
AutomaticLogin=${USERNAME}

[security]
[xdmcp]
[chooser]
[debug]
EOF
fi
echo "  OK"

echo ""
echo "Instalando GRUB..."
for fs in dev proc sys; do mount --bind "/$fs" "${TARGET}/$fs"; done
[ -d /sys/firmware/efi ] && \
    mount --bind /sys/firmware/efi/efivars "${TARGET}/sys/firmware/efi/efivars" 2>/dev/null || true

if [ "$FIRMWARE" = "UEFI" ]; then
    chroot "$TARGET" grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot/efi \
        --bootloader-id=Ubuntu \
        --recheck
else
    chroot "$TARGET" grub-install --target=i386-pc "$TARGET_DISK"
fi
chroot "$TARGET" update-grub
echo "  OK"

# ── Desmontar ─────────────────────────────────────────────────────────────────
[ -d /sys/firmware/efi ] && \
    umount "${TARGET}/sys/firmware/efi/efivars" 2>/dev/null || true
for fs in sys proc dev; do umount "$TARGET/$fs" 2>/dev/null || true; done
[ -n "$EFI_PART" ] && umount "${TARGET}/boot/efi" 2>/dev/null || true
umount "$TARGET" 2>/dev/null || true

# ── Fin ───────────────────────────────────────────────────────────────────────
echo ""
hr
echo "Instalación completada."
hr
echo "  Usuario : $USERNAME"
echo "  Autologin : $GDM_AUTOLOGIN"
echo ""
echo "Reinicia el sistema y retira el medio de instalación."
echo ""
