#!/bin/bash
# MÓDULO 01: Preparación de disco (solo instalación limpia)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${TARGET:-/mnt/ubuntu}"

# FIRMWARE es exportado por install.sh antes de llamar a este módulo
: "${FIRMWARE:?'Ejecuta install.sh, no este módulo directamente.'}"
echo

# Listar discos disponibles
echo "Discos disponibles:"
mapfile -t DISKS < <(lsblk -d -n -p -o NAME,TYPE | awk '$2=="disk"{print $1}')
if [ ${#DISKS[@]} -eq 0 ]; then
    echo "No se encontraron discos disponibles"
    exit 1
fi

for i in "${!DISKS[@]}"; do
    disk="${DISKS[$i]}"
    size=$(lsblk -d -n -o SIZE "$disk")
    model=$(lsblk -d -n -o MODEL "$disk" | xargs)
    echo "  $((i+1))) $disk  $size  $model"
done

echo
read -p "Selecciona disco [1]: " choice
choice=${choice:-1}
idx=$((choice - 1))
if [ $idx -lt 0 ] || [ $idx -ge ${#DISKS[@]} ]; then
    echo "Selección inválida"
    exit 1
fi

TARGET_DISK="${DISKS[$idx]}"
echo
echo "Disco seleccionado: $TARGET_DISK"
echo

# Desmontar particiones y swap
for part in $(lsblk -n -p -o NAME "$TARGET_DISK" | grep -v "^${TARGET_DISK}$"); do
    umount -f "$part" 2>/dev/null || true
done
swapoff -a 2>/dev/null || true

# Borrar tabla de particiones y limpiar disco
wipefs -a "$TARGET_DISK"
dd if=/dev/zero of="$TARGET_DISK" bs=1M count=4 conv=fsync 2>/dev/null || true
dd if=/dev/zero of="$TARGET_DISK" bs=512 count=34 seek=$(( $(blockdev --getsz "$TARGET_DISK") - 34 )) conv=fsync 2>/dev/null || true

# Crear tabla de particiones y particiones
if [ "$FIRMWARE" = "UEFI" ]; then
    parted -s "$TARGET_DISK" mklabel gpt
    parted -s "$TARGET_DISK" mkpart EFI fat32 1MiB 513MiB
    parted -s "$TARGET_DISK" set 1 esp on
    parted -s "$TARGET_DISK" mkpart root ext4 513MiB 100%
    EFI_PART="${TARGET_DISK}1"
    ROOT_PART="${TARGET_DISK}2"
else
    parted -s "$TARGET_DISK" mklabel msdos
    parted -s "$TARGET_DISK" mkpart primary ext4 1MiB 100%
    parted -s "$TARGET_DISK" set 1 boot on
    EFI_PART=""
    ROOT_PART="${TARGET_DISK}1"
fi

# Esperar a que el kernel reconozca las particiones
partprobe "$TARGET_DISK" 2>/dev/null || true
udevadm settle 2>/dev/null || true
sleep 1

# Formatear particiones
if [ "$FIRMWARE" = "UEFI" ]; then
    mkfs.fat -F32 -n EFI "$EFI_PART"
    echo "EFI formateada: $EFI_PART (FAT32)"
fi

mkfs.ext4 -F -L ubuntu-root -O has_journal,extent,huge_file,flex_bg,metadata_csum,64bit,dir_nlink,extra_isize "$ROOT_PART"
echo "Root formateada: $ROOT_PART (ext4)"

# Exportar variables para uso posterior
cat > "${SCRIPT_DIR}/../partition.info" << EOF
TARGET_DISK="$TARGET_DISK"
EFI_PART="$EFI_PART"
ROOT_PART="$ROOT_PART"
TARGET="$TARGET"
EOF

echo
 echo "Disco preparado para instalación limpia."
echo "Disco: $TARGET_DISK"
[ -n "$EFI_PART" ] && echo "EFI: $EFI_PART"
echo "Root: $ROOT_PART"
echo
exit 0
