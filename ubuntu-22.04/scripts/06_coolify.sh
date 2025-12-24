#!/bin/bash

# =============================================================================
# Script de Instalación de Coolify
# Ubuntu 22.04
# =============================================================================
# Documentación: https://coolify.io/docs/installation
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
COOLIFY_DOMAIN="${COOLIFY_DOMAIN:-}"
COOLIFY_EMAIL="${COOLIFY_EMAIL:-}"

echo "=============================================="
echo "  Instalación de Coolify"
echo "=============================================="
echo ""
echo "Coolify es una alternativa open-source a Heroku/Netlify/Vercel"
echo "que te permite hacer self-hosting de aplicaciones."
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

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo "Error: Docker no está instalado"
    echo "Por favor, ejecuta primero el script 04_docker.sh"
    exit 1
else
    echo "✓ Docker está instalado"
    docker --version
fi

# Verificar requisitos mínimos del sistema
echo ""
echo "Verificando requisitos del sistema..."

# Verificar memoria RAM (mínimo 2GB recomendado)
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 2 ]; then
    echo "ADVERTENCIA: Se recomiendan al menos 2GB de RAM. Tienes ${TOTAL_RAM}GB"
    echo "La instalación puede continuar pero el rendimiento podría verse afectado."
    read -p "¿Deseas continuar? (s/n): " CONTINUE
    if [ "$CONTINUE" != "s" ] && [ "$CONTINUE" != "S" ]; then
        echo "Instalación cancelada."
        exit 1
    fi
fi

# Verificar espacio en disco (mínimo 10GB recomendado)
AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 10 ]; then
    echo "ADVERTENCIA: Se recomiendan al menos 10GB de espacio libre. Tienes ${AVAILABLE_SPACE}GB"
fi

# =============================================================================
# Instalación de Coolify
# =============================================================================

echo ""
echo "[2/3] Instalando Coolify..."
echo ""
echo "NOTA: Este proceso descargará e instalará Coolify usando Docker"
echo "      El proceso puede tardar varios minutos."
echo ""

# Descargar e instalar Coolify
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash

# Esperar a que Coolify esté listo
echo ""
echo "Esperando a que Coolify se inicie..."
sleep 15

# Verificar que Coolify está corriendo
MAX_RETRIES=12
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker ps | grep -q coolify; then
        echo "✓ Coolify se ha iniciado correctamente"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            echo "ADVERTENCIA: Coolify podría no haberse iniciado correctamente"
            echo "Verifica los contenedores con: docker ps -a"
            echo "Verifica los logs con: docker logs coolify"
        else
            echo "Esperando... ($RETRY_COUNT/$MAX_RETRIES)"
            sleep 5
        fi
    fi
done

# =============================================================================
# Configuración del Firewall
# =============================================================================

echo ""
echo "[3/3] Configurando firewall..."

# Verificar si UFW está instalado y activo
if command -v ufw &> /dev/null; then
    echo "Abriendo puertos para Coolify..."
    
    # Puerto 8000 - Interfaz web de Coolify
    ufw allow 8000/tcp comment 'Coolify Web UI'
    
    # Puerto 6001 - WebSocket para Coolify
    ufw allow 6001/tcp comment 'Coolify WebSocket'
    
    # Puertos HTTP/HTTPS para aplicaciones
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    # Recargar UFW
    ufw reload
    
    echo "✓ Puertos configurados en UFW"
else
    echo "ADVERTENCIA: UFW no está instalado"
    echo "Asegúrate de abrir manualmente los puertos:"
    echo "  - 8000 (Coolify Web UI)"
    echo "  - 6001 (Coolify WebSocket)"
    echo "  - 80 (HTTP)"
    echo "  - 443 (HTTPS)"
fi

# =============================================================================
# Finalización
# =============================================================================

echo ""
echo "=============================================="
echo "  Coolify instalado correctamente!"
echo "=============================================="
echo ""
echo "Accede a Coolify en:"
echo "  http://$(hostname -I | awk '{print $1}'):8000"
echo ""

if [ -n "$COOLIFY_DOMAIN" ]; then
    echo "  o http://${COOLIFY_DOMAIN}:8000"
    echo ""
fi

echo "Pasos siguientes:"
echo "  1. Accede a la interfaz web"
echo "  2. Completa la configuración inicial"
echo "  3. Crea tu cuenta de administrador"
echo "  4. Configura tu primera aplicación"
echo ""

if [ -n "$COOLIFY_EMAIL" ]; then
    echo "Email configurado: $COOLIFY_EMAIL"
    echo ""
fi

echo "IMPORTANTE:"
echo "  - Configura SSL/TLS para producción"
echo "  - Usa un dominio personalizado para el panel"
echo "  - Revisa la documentación oficial"
echo ""

echo "Comandos útiles:"
echo "  - Ver logs: docker logs -f coolify"
echo "  - Reiniciar: docker restart coolify"
echo "  - Estado: docker ps | grep coolify"
echo "  - Detener: docker stop coolify"
echo "  - Actualizar: curl -fsSL https://cdn.coollabs.io/coolify/upgrade.sh | bash"
echo ""

echo "Documentación: https://coolify.io/docs"
echo ""
