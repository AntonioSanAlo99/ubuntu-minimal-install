# ubuntu-minimal-install

Instalador modular minimalista y reproducible de Ubuntu basado en `mmdebstrap`.

Sin `ubiquity`. Sin `subiquity`. Sin `debconf` interactivo. Solo scripts POSIX shell auditables.

## Requisitos

- `mmdebstrap`, `ubuntu-keyring`
- `parted`, `wipefs`, `mkfs.fat`, `mkfs.ext4`
- `python3` (para configuración de GDM)

## Uso

```sh
sudo ./install.sh
```

El asistente interactivo te guiará por todos los pasos:

1. **Perfil** — `gnome` o `minimal`
2. **Sistema** — hostname, timezone, locale, teclado
3. **Usuario** — nombre de login, nombre completo, contraseña
4. **Root** — contraseña opcional (por defecto bloqueado, acceso solo por sudo)
5. **GDM autologin** — inicio de sesión automático (solo perfil gnome)
6. **Disco** — selección y particionado (¡destructivo!)
7. **Confirmación** — resumen antes de ejecutar

También puedes pasar el perfil como argumento para saltarte el paso 1:

```sh
sudo ./install.sh gnome
sudo ./install.sh minimal
```

## Perfiles

| Perfil    | Descripción                         |
|-----------|-------------------------------------|
| `minimal` | Base + systemd, sin entorno gráfico |
| `gnome`   | Escritorio GNOME completo con GDM   |

## Estructura

```
ubuntu-minimal-install/
├── install.sh               # Orquestador + asistente interactivo
├── config.sh                # Valores por defecto (sobreescritos por el asistente)
├── partition.info           # Generado por módulo 01 (no editar)
├── modules/
│   └── 01-disk.sh           # Particionado interactivo
├── hooks/
│   ├── customize01.sh       # debconf + policy-rc.d
│   ├── customize02.sh       # NetworkManager
│   ├── customize03.sh       # Locale
│   ├── customize04.sh       # Timezone
│   ├── customize05.sh       # Hostname + teclado
│   ├── customize06.sh       # systemctl enable + cleanup
│   ├── customize07.sh       # dracut initramfs
│   ├── customize08.sh       # ★ Crear usuario + contraseñas + sudo
│   └── customize09.sh       # ★ Configurar GDM autologin
└── profiles/
    ├── minimal.sh
    └── gnome.sh
```

## Variables de entorno para hooks

Los hooks reciben estas variables exportadas por `install.sh`:

| Variable         | Descripción                                  |
|------------------|----------------------------------------------|
| `USERNAME`       | Login del usuario a crear                    |
| `USER_FULLNAME`  | Nombre completo (campo GECOS)                |
| `USER_PASSWORD`  | Contraseña del usuario                       |
| `ROOT_PASSWORD`  | Contraseña de root (vacío = cuenta bloqueada)|
| `GDM_AUTOLOGIN`  | `yes` / `no`                                 |
| `HOSTNAME`       | Nombre del equipo                            |
| `TIMEZONE`       | Zona horaria (p.ej. `Europe/Madrid`)         |
| `LOCALE`         | Locale del sistema                           |
| `KEYMAP`         | Distribución de teclado                      |

## Flujo de instalación

```
install.sh
  │
  ├── Asistente interactivo (pasos 1-6)
  ├── modules/01-disk.sh       → partition.info
  ├── mount ROOT + EFI
  ├── mmdebstrap + hooks/      → $TARGET
  │     ├── customize01–07     (sistema base)
  │     ├── customize08        (usuario + contraseñas)
  │     └── customize09        (GDM autologin)
  ├── genera fstab
  └── grub-install + update-grub
```
