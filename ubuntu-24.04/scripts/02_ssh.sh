#!/bin/bash

# =============================================================================
# Script de Configuración de SSH
# Ubuntu 24.04
# =============================================================================
# Configura SSH con llaves públicas y seguridad mejorada
# Maneja automáticamente el socket activation de systemd
# =============================================================================

set -e

# =============================================================================
# Cargar variables desde .env
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ -f "$ENV_FILE" ]; then
    echo "Cargando configuración desde .env..."
    source "$ENV_FILE"
else
    echo "ADVERTENCIA: No se encontró archivo .env en ${ENV_FILE}"
    echo "Usando valores por defecto..."
fi

# Valores por defecto si no están definidos en .env
SSH_PORT="${SSH_PORT:-22}"
SSH_ADMIN_KEYS="${SSH_ADMIN_KEYS:-}"
SSH_GITHUB_KEY="${SSH_GITHUB_KEY:-}"
SSH_DISABLE_PASSWORD="${SSH_DISABLE_PASSWORD:-yes}"
SSH_DISABLE_ROOT="${SSH_DISABLE_ROOT:-yes}"
SSH_ADMIN_USER="${SSH_ADMIN_USER:-root}"

echo "================================================"
echo "  Configurando SSH - Ubuntu 24.04"
echo "================================================"

# =============================================================================
# Verificar usuario
# =============================================================================

echo ""
echo "[1/4] Verificando usuario..."

# Determinar el usuario para configurar las llaves
if [ "$SSH_ADMIN_USER" = "root" ]; then
    TARGET_USER="root"
    TARGET_HOME="/root"
else
    TARGET_USER="$SSH_ADMIN_USER"
    TARGET_HOME="/home/$SSH_ADMIN_USER"
fi

# Crear directorio .ssh si no existe
SSH_DIR="${TARGET_HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chown "$TARGET_USER:$TARGET_USER" "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    echo "✓ Directorio .ssh creado: $SSH_DIR"
fi

# Crear archivo authorized_keys si no existe
if [ ! -f "$AUTHORIZED_KEYS" ]; then
    touch "$AUTHORIZED_KEYS"
    chown "$TARGET_USER:$TARGET_USER" "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
    echo "✓ Archivo authorized_keys creado: $AUTHORIZED_KEYS"
fi

# Agregar llaves de administrador (soporta múltiples llaves)
if [ -n "$SSH_ADMIN_KEYS" ]; then
    ADMIN_KEYS_COUNT=0
    # Procesar cada llave (separadas por nueva línea en el archivo de llaves)
    if [ -f "${SCRIPT_DIR}/../ssh_admin_keys.txt" ]; then
        echo "Leyendo llaves desde ssh_admin_keys.txt..."
        while IFS= read -r key || [ -n "$key" ]; do
            # Ignorar líneas vacías y comentarios
            if [ -n "$key" ] && [[ ! "$key" =~ ^[[:space:]]*# ]]; then
                if ! grep -qF "$key" "$AUTHORIZED_KEYS" 2>/dev/null; then
                    echo "$key" >> "$AUTHORIZED_KEYS"
                    ADMIN_KEYS_COUNT=$((ADMIN_KEYS_COUNT + 1))
                fi
            fi
        done < "${SCRIPT_DIR}/../ssh_admin_keys.txt"
        echo "✓ $ADMIN_KEYS_COUNT llaves de administrador agregadas"
    else
        # Fallback: usar variable de entorno directamente (una sola llave)
        if ! grep -qF "$SSH_ADMIN_KEYS" "$AUTHORIZED_KEYS" 2>/dev/null; then
            echo "$SSH_ADMIN_KEYS" >> "$AUTHORIZED_KEYS"
            echo "✓ Llave del administrador agregada"
        else
            echo "✓ Llave del administrador ya existe"
        fi
    fi
else
    echo "⚠ No se especificó SSH_ADMIN_KEYS en .env ni archivo ssh_admin_keys.txt"
fi

# Agregar llave de GitHub
if [ -n "$SSH_GITHUB_KEY" ]; then
    if ! grep -q "$SSH_GITHUB_KEY" "$AUTHORIZED_KEYS" 2>/dev/null; then
        echo "$SSH_GITHUB_KEY" >> "$AUTHORIZED_KEYS"
        echo "✓ Llave de GitHub agregada"
    else
        echo "✓ Llave de GitHub ya existe"
    fi
else
    echo "⚠ No se especificó SSH_GITHUB_KEY en .env"
fi

# Asegurar permisos correctos
chown "$TARGET_USER:$TARGET_USER" "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

echo ""
echo "Llaves autorizadas ubicadas en: $AUTHORIZED_KEYS"

# =============================================================================
# Configurar sshd_config
# =============================================================================

echo ""
echo "[2/4] Configurando archivo sshd_config..."

# Crear backup del archivo original
if [ ! -f /etc/ssh/sshd_config.backup ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    echo "✓ Backup creado: /etc/ssh/sshd_config.backup"
fi

# Cambiar puerto SSH si es diferente de 22
if [ "$SSH_PORT" != "22" ]; then
    echo "Cambiando puerto SSH a: $SSH_PORT"
    sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
    sed -i "s/^Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
    sed -i "s/^Port [0-9]*/Port $SSH_PORT/" /etc/ssh/sshd_config
    echo "✓ Puerto SSH configurado: $SSH_PORT"
fi

# =============================================================================
# Configurar seguridad SSH
# =============================================================================

echo ""
echo "[3/4] Configurando seguridad SSH..."

# Deshabilitar autenticación por contraseña si está configurado
if [ "$SSH_DISABLE_PASSWORD" = "yes" ]; then
    echo "Deshabilitando autenticación por contraseña..."
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    
    # Asegurar que PubkeyAuthentication esté habilitado
    sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    echo "✓ Autenticación por contraseña deshabilitada"
    echo "✓ Autenticación por llave pública habilitada"
else
    echo "Autenticación por contraseña habilitada"
fi

# Deshabilitar login root por SSH si está configurado
if [ "$SSH_DISABLE_ROOT" = "yes" ]; then
    echo "Deshabilitando login root por SSH..."
    sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    echo "✓ Login root deshabilitado"
else
    echo "Login de root habilitado"
fi

# Aplicar configuraciones de seguridad adicionales
echo "Aplicando configuraciones de seguridad adicionales..."

# Deshabilitar autenticación challenge-response
sed -i 's/^#ChallengeResponseAuthentication no/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

# Deshabilitar X11 forwarding (si no se necesita)
sed -i 's/^X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config

# Limitar tiempo de autenticación
grep -q "^LoginGraceTime" /etc/ssh/sshd_config || echo "LoginGraceTime 60" >> /etc/ssh/sshd_config

# Limitar sesiones concurrentes
grep -q "^MaxStartups" /etc/ssh/sshd_config || echo "MaxStartups 10:30:60" >> /etc/ssh/sshd_config

echo "✓ Configuraciones de seguridad aplicadas"

# =============================================================================
# Reiniciar servicio SSH
# =============================================================================

echo ""
echo "[4/4] Reiniciando servicio SSH..."

# Ubuntu 24.04 usa ssh.service por defecto
SSH_SERVICE="ssh"

# Ubuntu 24.04: Deshabilitar socket activation si el puerto no es 22
# El socket solo escucha en el puerto 22, ignorando sshd_config
if [ "$SSH_PORT" != "22" ]; then
    if systemctl is-enabled ssh.socket &>/dev/null; then
        echo "Deshabilitando ssh.socket (Ubuntu 24.04)..."
        systemctl stop ssh.socket
        systemctl disable ssh.socket
        systemctl enable ssh.service
        echo "✓ Socket deshabilitado, usando servicio tradicional"
    fi
fi

# Verificar configuración antes de reiniciar
if sshd -t; then
    echo "✓ Configuración SSH válida"
    systemctl restart "$SSH_SERVICE"
    echo "✓ Servicio SSH reiniciado"
else
    echo "ERROR: La configuración SSH tiene errores"
    echo "Restaurando backup..."
    cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
    systemctl restart "$SSH_SERVICE"
    exit 1
fi

# Verificar que SSH está escuchando en el puerto correcto
sleep 2
if ss -tlnp | grep -q ":${SSH_PORT} "; then
    echo "✓ SSH escuchando en puerto $SSH_PORT"
else
    echo "⚠ ADVERTENCIA: SSH no está escuchando en el puerto $SSH_PORT"
    echo "  Verifica manualmente: ss -tlnp | grep sshd"
fi

# =============================================================================
# Finalización
# =============================================================================

echo ""
echo "=============================================="
echo "  SSH configurado correctamente"
echo "=============================================="
echo ""
echo "Configuración aplicada:"
echo "  - Puerto SSH: $SSH_PORT"
echo "  - Usuario: $TARGET_USER"
echo "  - Llaves autorizadas: $AUTHORIZED_KEYS"
echo "  - Auth por contraseña: $([ "$SSH_DISABLE_PASSWORD" = "yes" ] && echo "Deshabilitada" || echo "Habilitada")"
echo "  - Login root: $([ "$SSH_DISABLE_ROOT" = "yes" ] && echo "Deshabilitado" || echo "Habilitado")"
echo ""

if [ -n "$SSH_ADMIN_KEYS" ] || [ -n "$SSH_GITHUB_KEY" ]; then
    echo "IMPORTANTE: Prueba tu conexión SSH en una nueva terminal ANTES de cerrar esta sesión:"
    echo "  ssh -p $SSH_PORT $TARGET_USER@$(hostname -I | awk '{print $1}')"
    echo ""
    if [ "$SSH_DISABLE_PASSWORD" = "yes" ]; then
        echo "ADVERTENCIA: La autenticación por contraseña está deshabilitada."
        echo "             Asegúrate de tener acceso con tu llave privada."
    fi
else
    echo "ADVERTENCIA: No se agregaron llaves SSH."
    echo "             Considera crear ssh_admin_keys.txt y/o agregar SSH_GITHUB_KEY en .env"
fi

echo ""
