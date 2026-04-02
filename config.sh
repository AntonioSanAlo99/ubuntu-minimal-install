#!/bin/sh

# ── Mirror y suite ────────────────────────────────────────────────────────────
MIRROR="http://archive.ubuntu.com/ubuntu/"
SUITE="questing"
COMPONENTS="main,restricted,universe,multiverse"

# ── Punto de montaje ──────────────────────────────────────────────────────────
TARGET="/mnt/ubuntu"

# ── Configuración del sistema (sobreescrita por el asistente interactivo) ─────
HOSTNAME="ubuntu"
TIMEZONE="Europe/Madrid"
LOCALE="es_ES.UTF-8"
KEYMAP="es"

# ── Usuario inicial ───────────────────────────────────────────────────────────
# Estas variables se rellenan en el asistente interactivo de install.sh
USERNAME=""
USER_FULLNAME=""
USER_PASSWORD=""
ROOT_PASSWORD=""

# ── GDM autologin ─────────────────────────────────────────────────────────────
# "yes" activa el inicio de sesión automático en GDM para $USERNAME
GDM_AUTOLOGIN="no"

# ── Paquete de GRUB ───────────────────────────────────────────────────────────
# Se autodetecta en install.sh según el firmware del sistema:
#   BIOS → grub-pc
#   UEFI → grub-efi-amd64

# ── Directorio de hooks ───────────────────────────────────────────────────────
HOOK_DIR="$(dirname "$0")/hooks"
