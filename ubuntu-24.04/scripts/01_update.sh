#!/bin/bash

# =============================================================================
# Script: 01_update.sh
# Descripción: Actualiza los repositorios y paquetes sin cambiar la versión de Ubuntu
# Ubuntu 24.04
# =============================================================================

set -e  # Salir si hay algún error

echo "================================================"
echo "  Actualizando sistema Ubuntu 24.04"
echo "================================================"

# Actualizar lista de paquetes
echo ""
echo "[1/3] Actualizando lista de repositorios..."
apt-get update

# Actualizar paquetes instalados (sin cambiar versión de Ubuntu)
echo ""
echo "[2/3] Actualizando paquetes (sin dist-upgrade)..."
apt-get upgrade -y

# Limpiar paquetes no necesarios
echo ""
echo "[3/3] Limpiando paquetes innecesarios..."
apt-get autoremove -y
apt-get autoclean

echo ""
echo "================================================"
echo "  Sistema actualizado correctamente"
echo "================================================"
