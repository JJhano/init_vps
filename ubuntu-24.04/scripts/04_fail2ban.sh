#!/bin/bash

# =============================================================================
# Script de Configuración de Fail2ban
# Ubuntu 24.04
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
SSH_PORT=${SSH_PORT:-22}
FAIL2BAN_WHITELIST=${FAIL2BAN_WHITELIST:-"127.0.0.1/8 ::1"}
FAIL2BAN_MAXRETRY=${FAIL2BAN_MAXRETRY:-3}
FAIL2BAN_BANTIME=${FAIL2BAN_BANTIME:-1h}

echo "=========================================="
echo "Configurando Fail2ban..."
echo "=========================================="

echo ""
echo "[1/2] Instalando Fail2ban..."
apt install -y fail2ban

echo "[2/2] Configurando Fail2ban..."

# Crear archivo de configuración local (no modificar jail.conf directamente)
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# Tiempo de baneo por defecto
bantime = 10m

# Ventana de tiempo para contar intentos fallidos
findtime = 10m

# Número de intentos antes de banear
maxretry = 5

# Acción por defecto
banaction = iptables-multiport

# IPs en whitelist (nunca serán baneadas)
ignoreip = ${FAIL2BAN_WHITELIST}

# Backend para monitorear logs
backend = systemd

[sshd]
enabled = true
port = ${SSH_PORT}
filter = sshd
logpath = /var/log/auth.log
maxretry = ${FAIL2BAN_MAXRETRY}
bantime = ${FAIL2BAN_BANTIME}
EOF

# Reiniciar Fail2ban para aplicar configuración
systemctl restart fail2ban
systemctl enable fail2ban

echo ""
echo "=========================================="
echo "Fail2ban configurado correctamente!"
echo "=========================================="
echo ""
echo "Configuración SSH:"
echo "  - Puerto: ${SSH_PORT}"
echo "  - Intentos máximos: ${FAIL2BAN_MAXRETRY}"
echo "  - Tiempo de baneo: ${FAIL2BAN_BANTIME}"
echo "  - Whitelist: ${FAIL2BAN_WHITELIST}"
echo ""
echo "Comandos útiles:"
echo "  fail2ban-client status       - Ver estado general"
echo "  fail2ban-client status sshd  - Ver IPs baneadas en SSH"
echo "  fail2ban-client unban <IP>   - Desbanear una IP"
echo ""

fail2ban-client status
