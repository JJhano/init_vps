#!/bin/bash

# =============================================================================
# Script de Instalación de Netdata
# Ubuntu 22.04
# =============================================================================
# Documentación: https://learn.netdata.cloud/
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
NETDATA_PORT="${NETDATA_PORT:-19999}"
NETDATA_CLAIM_TOKEN="${NETDATA_CLAIM_TOKEN:-}"
NETDATA_CLAIM_ROOMS="${NETDATA_CLAIM_ROOMS:-}"
NETDATA_CLAIM_URL="${NETDATA_CLAIM_URL:-https://app.netdata.cloud}"

echo "=============================================="
echo "  Instalación de Netdata"
echo "=============================================="
echo ""
echo "Netdata es una herramienta de monitoreo en tiempo real"
echo "con dashboard web interactivo y alertas inteligentes."
echo ""

# =============================================================================
# Verificar prerequisitos
# =============================================================================

echo "[1/3] Verificando prerequisitos..."

# Verificar si se está ejecutando como root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: Este script debe ejecutarse como root"
    exit 1
fi

# Verificar que el puerto esté disponible
if netstat -tuln 2>/dev/null | grep -q ":$NETDATA_PORT " || ss -tuln 2>/dev/null | grep -q ":$NETDATA_PORT "; then
    echo "ADVERTENCIA: El puerto $NETDATA_PORT ya está en uso"
    read -p "¿Deseas continuar de todos modos? (s/n): " CONTINUE
    if [ "$CONTINUE" != "s" ] && [ "$CONTINUE" != "S" ]; then
        echo "Instalación cancelada."
        exit 1
    fi
else
    echo "✓ Puerto $NETDATA_PORT disponible"
fi

# Instalar dependencias necesarias
echo ""
echo "Instalando dependencias..."
apt update
apt install -y curl wget

# =============================================================================
# Instalación de Netdata
# =============================================================================

echo ""
echo "[2/3] Instalando Netdata..."
echo ""
echo "NOTA: El instalador oficial descargará e instalará Netdata"
echo "      Este proceso tarda aproximadamente 2-5 minutos."
echo ""

# Descargar e instalar Netdata usando el instalador oficial
if [ -n "$NETDATA_CLAIM_TOKEN" ] && [ -n "$NETDATA_CLAIM_ROOMS" ]; then
    echo "Instalando con conexión a Netdata Cloud..."
    wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh && \
    sh /tmp/netdata-kickstart.sh --claim-token "$NETDATA_CLAIM_TOKEN" \
        --claim-rooms "$NETDATA_CLAIM_ROOMS" \
        --claim-url "$NETDATA_CLAIM_URL" \
        --stable-channel --disable-telemetry --non-interactive
else
    echo "Instalando en modo standalone (sin Netdata Cloud)..."
    wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh && \
    sh /tmp/netdata-kickstart.sh --stable-channel --disable-telemetry --non-interactive
fi

# Verificar instalación
if systemctl is-active --quiet netdata; then
    echo "✓ Netdata instalado y en ejecución"
else
    echo "⚠ Netdata instalado pero podría no estar corriendo"
    echo "Intentando iniciar Netdata..."
    systemctl start netdata
    systemctl enable netdata
fi

# =============================================================================
# Configuración adicional
# =============================================================================

echo ""
echo "Configurando Netdata..."

# Cambiar puerto si no es el por defecto
if [ "$NETDATA_PORT" != "19999" ]; then
    echo "Configurando puerto personalizado: $NETDATA_PORT"
    
    NETDATA_CONFIG="/etc/netdata/netdata.conf"
    
    # Crear archivo de configuración si no existe
    if [ ! -f "$NETDATA_CONFIG" ]; then
        /usr/sbin/netdata -W set "web" "default port" "$NETDATA_PORT" -c "$NETDATA_CONFIG"
    else
        # Modificar puerto existente
        sed -i "s/^[[:space:]]*default port[[:space:]]*=.*/    default port = $NETDATA_PORT/" "$NETDATA_CONFIG"
    fi
    
    # Reiniciar Netdata
    systemctl restart netdata
    echo "✓ Puerto configurado"
fi

# Configurar acceso desde cualquier IP (por defecto solo localhost)
NETDATA_CONFIG="/etc/netdata/netdata.conf"
if [ -f "$NETDATA_CONFIG" ]; then
    # Permitir conexiones desde cualquier IP
    if grep -q "bind to = localhost" "$NETDATA_CONFIG" 2>/dev/null; then
        sed -i 's/bind to = localhost/bind to = */g' "$NETDATA_CONFIG"
        systemctl restart netdata
        echo "✓ Acceso remoto habilitado"
    fi
fi

# =============================================================================
# Configuración del Firewall
# =============================================================================

echo ""
echo "[3/3] Configurando firewall..."

if command -v ufw &> /dev/null; then
    echo "Abriendo puerto $NETDATA_PORT en UFW..."
    ufw allow ${NETDATA_PORT}/tcp comment 'Netdata'
    ufw reload
    echo "✓ Puerto configurado en UFW"
else
    echo "ADVERTENCIA: UFW no está instalado"
    echo "Asegúrate de abrir el puerto $NETDATA_PORT manualmente"
fi

# =============================================================================
# Finalización
# =============================================================================

echo ""
echo "=============================================="
echo "  Netdata instalado correctamente!"
echo "=============================================="
echo ""
echo "Accede al dashboard en:"
echo "  http://$(hostname -I | awk '{print $1}'):${NETDATA_PORT}"
echo ""

if [ -n "$NETDATA_CLAIM_TOKEN" ]; then
    echo "✓ Conectado a Netdata Cloud"
    echo "  Accede también en: https://app.netdata.cloud"
    echo ""
fi

echo "Características:"
echo "  ✓ Monitoreo en tiempo real (actualización por segundo)"
echo "  ✓ Más de 2000 métricas recopiladas automáticamente"
echo "  ✓ Dashboard web interactivo"
echo "  ✓ Alertas inteligentes"
echo "  ✓ Muy ligero (~1% CPU, ~50-100MB RAM)"
echo ""

echo "Métricas monitoreadas:"
echo "  - CPU (por core)"
echo "  - Memoria RAM y Swap"
echo "  - Disco (I/O, espacio)"
echo "  - Red (tráfico, conexiones)"
echo "  - Procesos y aplicaciones"

if docker ps &>/dev/null 2>&1; then
    echo "  - Contenedores Docker detectados ✓"
fi

if systemctl is-active --quiet nginx 2>/dev/null || systemctl is-active --quiet apache2 2>/dev/null; then
    echo "  - Servidor web detectado ✓"
fi

if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
    echo "  - Base de datos detectada ✓"
fi

echo ""
echo "Comandos útiles:"
echo "  - Estado: systemctl status netdata"
echo "  - Reiniciar: systemctl restart netdata"
echo "  - Logs: journalctl -u netdata -f"
echo "  - Configuración: /etc/netdata/netdata.conf"
echo ""

echo "SEGURIDAD IMPORTANTE:"
echo "  Por defecto, Netdata NO tiene autenticación."
echo "  Opciones para asegurar el acceso:"
echo ""
echo "  1. Acceder solo vía VPN/SSH tunnel:"
echo "     ssh -L ${NETDATA_PORT}:localhost:${NETDATA_PORT} usuario@servidor"
echo ""
echo "  2. Configurar nginx como proxy con autenticación:"
echo "     Ver: https://learn.netdata.cloud/docs/netdata-agent/securing-netdata-agents"
echo ""
echo "  3. Usar Netdata Cloud (gratis, autenticado):"
echo "     https://app.netdata.cloud"
echo ""

if [ -z "$NETDATA_CLAIM_TOKEN" ]; then
    echo "OPCIONAL - Conectar a Netdata Cloud (gratis):"
    echo "  1. Crea cuenta en: https://app.netdata.cloud"
    echo "  2. Obtén el claim token"
    echo "  3. Ejecuta: netdata-claim.sh -token=TOKEN -rooms=ROOM_ID -url=https://app.netdata.cloud"
    echo ""
fi

echo "Documentación: https://learn.netdata.cloud/"
echo ""
