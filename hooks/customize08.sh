#!/bin/sh
# HOOK 08 — Crear usuario inicial y establecer contraseñas
set -e

# Variables requeridas: USERNAME, USER_FULLNAME, USER_PASSWORD
# Variables opcionales: ROOT_PASSWORD (vacío = root bloqueado)

if [ -z "$USERNAME" ] || [ -z "$USER_PASSWORD" ]; then
    echo "  [hook08] ERROR: USERNAME y USER_PASSWORD son obligatorios." >&2
    exit 1
fi

echo "  [hook08] Creando usuario '${USERNAME}'..."

# Crear usuario con shell bash, directorio home y grupo primario propio
chroot "$1" useradd \
    --create-home \
    --shell /bin/bash \
    --comment "${USER_FULLNAME:-$USERNAME}" \
    "$USERNAME"

# Establecer contraseña del usuario
printf '%s:%s\n' "$USERNAME" "$USER_PASSWORD" | chroot "$1" chpasswd

# Añadir al grupo sudo (sudo-rs lo respeta igual que sudo clásico)
chroot "$1" usermod -aG sudo "$USERNAME"

echo "  [hook08] Usuario '${USERNAME}' creado y añadido al grupo sudo."

# Contraseña de root
if [ -n "$ROOT_PASSWORD" ]; then
    printf 'root:%s\n' "$ROOT_PASSWORD" | chroot "$1" chpasswd
    echo "  [hook08] Contraseña de root establecida."
else
    # Bloquear cuenta root (no permite login directo)
    chroot "$1" passwd -l root
    echo "  [hook08] Cuenta root bloqueada (sin contraseña directa)."
fi
