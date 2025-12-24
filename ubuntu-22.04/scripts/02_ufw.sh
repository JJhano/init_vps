#!/bin/bash

# =============================================================================
# Script de Configuración de UFW (Uncomplicated Firewall)
# Ubuntu 22.04
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

echo "=========================================="
echo "Configurando UFW (Firewall)"
echo "=========================================="

# -----------------------------------------------------------------------------
# Configurar UFW
# -----------------------------------------------------------------------------
echo ""
echo "[1/2] Instalando UFW..."
apt install -y ufw

echo "[2/2] Configurando UFW..."

# Resetear reglas anteriores (por si acaso)
ufw --force reset

# Políticas por defecto: denegar entrada, permitir salida
ufw default deny incoming
ufw default allow outgoing

# Permitir SSH en el nuevo puerto (IMPORTANTE: para no perder acceso)
ufw allow ${SSH_PORT}/tcp comment 'SSH'

# Permitir HTTP y HTTPS (para servidores web)
ufw allow http
ufw allow https

# Habilitar UFW
echo "y" | ufw enable

echo ""
echo "=========================================="
echo "UFW configurado correctamente!"
echo "=========================================="
echo ""
echo "Puertos abiertos: SSH (${SSH_PORT}), HTTP (80), HTTPS (443)"
echo ""
echo "Comandos útiles:"
echo "  ufw status verbose    - Ver estado detallado"
echo "  ufw allow <puerto>    - Abrir un puerto"
echo "  ufw deny <puerto>     - Cerrar un puerto"
echo "  ufw delete allow <puerto> - Eliminar regla"
echo ""

ufw status verbose
