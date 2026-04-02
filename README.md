# ubuntu-minimal-install

Instalador modular y reproducible de Ubuntu basado en `mmdebstrap`.
Inspirado en la filosofía de [glaucus linux](https://github.com/glaucuslinux/glaucus)
y [archinstall](https://github.com/archlinux/archinstall).

Sin `ubiquity`. Sin `subiquity`. Sin `debconf` interactivo. Solo scripts POSIX sh auditables.

## Requisitos

- `mmdebstrap`
- `parted`, `wipefs`, `mkfs.fat`, `mkfs.ext4`
- Partición destino montable en `/mnt/ubuntu` (configurable en `config.sh`)

## Uso

```sh
# 1. Editar configuración
vim config.sh

# 2. Lanzar instalador (perfil por defecto: gnome)
sudo ./install.sh gnome

# Otros perfiles:
sudo ./install.sh minimal
sudo ./install.sh server
```

## Perfiles

| Perfil    | Descripción                          |
|-----------|--------------------------------------|
| `minimal` | Base + systemd, sin entorno gráfico  |
| `gnome`   | Escritorio GNOME completo            |
| `server`  | Minimal + openssh, ufw, fail2ban     |

## Estructura

```
ubuntu-minimal-install/
├── install.sh               # Orquestador principal
├── config.sh                # Variables globales
├── partition.info           # Generado por módulo 01 (no editar)
├── modules/
│   └── 01-disk.sh           # Particionado interactivo (limpio + dual boot)
├── hooks/
│   ├── customize01.sh       # debconf + policy-rc.d
│   ├── customize02.sh       # NetworkManager
│   ├── customize03.sh       # Locale
│   ├── customize04.sh       # Timezone
│   ├── customize05.sh       # Hostname + teclado
│   ├── customize06.sh       # systemctl enable + cleanup
│   └── customize07.sh       # dracut initramfs
└── profiles/
    ├── minimal.sh
    ├── gnome.sh
    └── server.sh
```

## Flujo de instalación

```
install.sh
  │
  ├── modules/01-disk.sh     → partition.info
  ├── mount ROOT + EFI
  ├── mmdebstrap + hooks/    → $TARGET
  ├── genera fstab
  └── grub-install + update-grub
```
