#!/bin/sh
# HOOK 09 — Configurar GDM (autologin opcional)
set -e

# Variables requeridas: GDM_AUTOLOGIN (yes/no), USERNAME
# Solo actúa si gdm3 está instalado en el sistema destino.

if ! chroot "$1" dpkg -l gdm3 2>/dev/null | grep -q '^ii'; then
    echo "  [hook09] gdm3 no instalado, omitiendo configuración GDM."
    exit 0
fi

GDM_CONF="$1/etc/gdm3/custom.conf"

# Crear directorio si no existe (instalaciones muy mínimas)
mkdir -p "$(dirname "$GDM_CONF")"

# Escribir configuración base si el archivo no existe aún
if [ ! -f "$GDM_CONF" ]; then
    cat > "$GDM_CONF" << 'EOF'
[daemon]

[security]

[xdmcp]

[chooser]

[debug]
EOF
fi

if [ "$GDM_AUTOLOGIN" = "yes" ] && [ -n "$USERNAME" ]; then
    echo "  [hook09] Activando autologin para '${USERNAME}' en GDM..."

    # Insertar o reemplazar bloque [daemon] con autologin
    python3 - "$GDM_CONF" "$USERNAME" << 'PYEOF'
import sys, re

conf_path = sys.argv[1]
username  = sys.argv[2]

with open(conf_path) as f:
    content = f.read()

autologin_block = (
    "[daemon]\n"
    f"AutomaticLoginEnable=True\n"
    f"AutomaticLogin={username}\n"
)

# Reemplazar sección [daemon] existente o añadirla al principio
if re.search(r'^\[daemon\]', content, re.MULTILINE):
    content = re.sub(
        r'\[daemon\][^\[]*',
        autologin_block + "\n",
        content,
        flags=re.DOTALL
    )
else:
    content = autologin_block + "\n" + content

with open(conf_path, 'w') as f:
    f.write(content)

print("  [hook09] custom.conf actualizado.")
PYEOF

else
    echo "  [hook09] Autologin desactivado; GDM usará pantalla de inicio de sesión normal."

    # Asegurar que no queden entradas de autologin residuales
    python3 - "$GDM_CONF" << 'PYEOF'
import sys, re

conf_path = sys.argv[1]

with open(conf_path) as f:
    content = f.read()

# Eliminar líneas AutomaticLogin* dentro de [daemon]
content = re.sub(r'^\s*AutomaticLoginEnable\s*=.*\n', '', content, flags=re.MULTILINE)
content = re.sub(r'^\s*AutomaticLogin\s*=.*\n',       '', content, flags=re.MULTILINE)

with open(conf_path, 'w') as f:
    f.write(content)
PYEOF

fi

echo "  [hook09] Configuración GDM completada."
