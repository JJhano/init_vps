#!/bin/bash

# =============================================================================
# Script de Instalación de Mailcow
# Ubuntu 22.04
# =============================================================================
# Documentación: https://docs.mailcow.email/
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
MAILCOW_HOSTNAME="${MAILCOW_HOSTNAME:-mail.example.com}"
MAILCOW_TIMEZONE="${MAILCOW_TIMEZONE:-America/New_York}"

echo "=============================================="
echo "  Instalación de Mailcow"
echo "=============================================="
echo ""
echo "Mailcow es una solución completa de servidor de email"
echo "con interfaz web, webmail, antispam y antivirus."
echo ""

# =============================================================================
# Verificar prerequisitos
# =============================================================================

echo "[1/5] Verificando prerequisitos..."

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

# Verificar Docker Compose
if ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose no está disponible"
    exit 1
else
    echo "✓ Docker Compose está disponible"
    docker compose version
fi

# Verificar requisitos mínimos del sistema
echo ""
echo "Verificando requisitos del sistema..."

# Verificar memoria RAM (mínimo 6GB recomendado para Mailcow)
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 6 ]; then
    echo "ADVERTENCIA: Se recomiendan al menos 6GB de RAM para Mailcow. Tienes ${TOTAL_RAM}GB"
    echo "Mailcow puede funcionar con menos RAM pero el rendimiento será limitado."
    read -p "¿Deseas continuar? (s/n): " CONTINUE
    if [ "$CONTINUE" != "s" ] && [ "$CONTINUE" != "S" ]; then
        echo "Instalación cancelada."
        exit 1
    fi
fi

# Verificar espacio en disco (mínimo 20GB recomendado)
AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 20 ]; then
    echo "ADVERTENCIA: Se recomiendan al menos 20GB de espacio libre. Tienes ${AVAILABLE_SPACE}GB"
fi

# Verificar hostname configurado
if [ "$MAILCOW_HOSTNAME" = "mail.example.com" ]; then
    echo ""
    echo "ADVERTENCIA: No has configurado MAILCOW_HOSTNAME en el archivo .env"
    echo "El hostname actual es: $MAILCOW_HOSTNAME"
    echo ""
    read -p "¿Deseas configurar un hostname ahora? (s/n): " CONFIG_HOSTNAME
    if [ "$CONFIG_HOSTNAME" = "s" ] || [ "$CONFIG_HOSTNAME" = "S" ]; then
        read -p "Ingresa el hostname (ej: mail.tudominio.com): " NEW_HOSTNAME
        MAILCOW_HOSTNAME="$NEW_HOSTNAME"
    fi
fi

echo ""
echo "Hostname configurado: $MAILCOW_HOSTNAME"
echo "Zona horaria: $MAILCOW_TIMEZONE"

# =============================================================================
# Verificar puertos disponibles
# =============================================================================

echo ""
echo "[2/5] Verificando puertos necesarios..."

REQUIRED_PORTS=(25 80 110 143 443 465 587 993 995)
PORTS_IN_USE=()

for port in "${REQUIRED_PORTS[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        PORTS_IN_USE+=($port)
    fi
done

if [ ${#PORTS_IN_USE[@]} -gt 0 ]; then
    echo "ERROR: Los siguientes puertos ya están en uso:"
    for port in "${PORTS_IN_USE[@]}"; do
        echo "  - Puerto $port"
    done
    echo ""
    echo "Mailcow requiere estos puertos libres:"
    echo "  - 25 (SMTP)"
    echo "  - 80 (HTTP)"
    echo "  - 110 (POP3)"
    echo "  - 143 (IMAP)"
    echo "  - 443 (HTTPS)"
    echo "  - 465 (SMTPS)"
    echo "  - 587 (Submission)"
    echo "  - 993 (IMAPS)"
    echo "  - 995 (POP3S)"
    echo ""
    echo "Si tienes Coolify instalado, debes usar un puerto alternativo o proxy reverso."
    exit 1
fi

echo "✓ Todos los puertos necesarios están disponibles"

# =============================================================================
# Descargar Mailcow
# =============================================================================

echo ""
echo "[3/5] Descargando Mailcow..."

# Crear directorio para Mailcow
MAILCOW_DIR="/opt/mailcow-dockerized"

if [ -d "$MAILCOW_DIR" ]; then
    echo "El directorio $MAILCOW_DIR ya existe."
    read -p "¿Deseas eliminarlo y reinstalar? (s/n): " REINSTALL
    if [ "$REINSTALL" = "s" ] || [ "$REINSTALL" = "S" ]; then
        cd "$MAILCOW_DIR"
        docker compose down -v 2>/dev/null || true
        cd /
        rm -rf "$MAILCOW_DIR"
    else
        echo "Instalación cancelada."
        exit 1
    fi
fi

# Clonar repositorio
cd /opt
git clone https://github.com/mailcow/mailcow-dockerized
cd mailcow-dockerized

# =============================================================================
# Configurar Mailcow
# =============================================================================

echo ""
echo "[4/5] Configurando Mailcow..."

# Generar configuración
./generate_config.sh <<EOF
$MAILCOW_HOSTNAME
$MAILCOW_TIMEZONE
EOF

# Configuraciones adicionales opcionales en mailcow.conf
if [ -f "mailcow.conf" ]; then
    echo "Aplicando configuraciones adicionales..."
    
    # Deshabilitar IPv6 si no está disponible
    if ! ip -6 addr show 2>/dev/null | grep -q "inet6"; then
        sed -i 's/IPV6_NETWORK=.*/IPV6_NETWORK=/g' mailcow.conf
        echo "IPv6 deshabilitado (no disponible en el sistema)"
    fi
fi

# =============================================================================
# Instalar y arrancar Mailcow
# =============================================================================

echo ""
echo "[5/5] Instalando y arrancando Mailcow..."
echo ""
echo "NOTA: Este proceso descargará todas las imágenes Docker necesarias."
echo "      Puede tardar 10-20 minutos dependiendo de tu conexión."
echo ""

# Pull de imágenes
docker compose pull

# Iniciar Mailcow
docker compose up -d

# Esperar a que los servicios estén listos
echo ""
echo "Esperando a que los servicios se inicien..."
sleep 30

# Verificar estado
echo ""
echo "Verificando estado de los contenedores..."
docker compose ps

# =============================================================================
# Configuración del Firewall
# =============================================================================

echo ""
echo "Configurando firewall..."

if command -v ufw &> /dev/null; then
    echo "Abriendo puertos para Mailcow..."
    
    # Puertos de email
    ufw allow 25/tcp comment 'SMTP'
    ufw allow 465/tcp comment 'SMTPS'
    ufw allow 587/tcp comment 'Submission'
    ufw allow 110/tcp comment 'POP3'
    ufw allow 995/tcp comment 'POP3S'
    ufw allow 143/tcp comment 'IMAP'
    ufw allow 993/tcp comment 'IMAPS'
    
    # Puertos web (si no están abiertos)
    ufw allow 80/tcp comment 'HTTP' 2>/dev/null || true
    ufw allow 443/tcp comment 'HTTPS' 2>/dev/null || true
    
    # Recargar UFW
    ufw reload
    
    echo "✓ Puertos configurados en UFW"
else
    echo "ADVERTENCIA: UFW no está instalado"
    echo "Asegúrate de abrir manualmente los puertos necesarios"
fi

# =============================================================================
# Finalización
# =============================================================================

echo ""
echo "=============================================="
echo "  Mailcow instalado correctamente!"
echo "=============================================="
echo ""
echo "Accede a la interfaz web en:"
echo "  https://${MAILCOW_HOSTNAME}"
echo "  o https://$(hostname -I | awk '{print $1}')"
echo ""
echo "Credenciales por defecto:"
echo "  Usuario: admin"
echo "  Contraseña: moohoo"
echo ""
echo "IMPORTANTE:"
echo "  1. Cambia la contraseña de administrador inmediatamente"
echo "  2. Configura los registros DNS (MX, SPF, DKIM, DMARC)"
echo "  3. Configura Let's Encrypt SSL en la interfaz web"
echo ""
echo "Comandos útiles:"
echo "  - Ver logs: cd $MAILCOW_DIR && docker compose logs -f"
echo "  - Reiniciar: cd $MAILCOW_DIR && docker compose restart"
echo "  - Detener: cd $MAILCOW_DIR && docker compose down"
echo "  - Actualizar: cd $MAILCOW_DIR && ./update.sh"
echo ""
echo "Documentación: https://docs.mailcow.email/"
echo ""
echo "SIGUIENTE PASO: Configura estos registros DNS:"
echo "  MX    @  10  ${MAILCOW_HOSTNAME}"
echo "  A     mail    $(hostname -I | awk '{print $1}')"
echo ""
echo "Ejecuta esto para ver los registros DKIM/SPF/DMARC:"
echo "  cd $MAILCOW_DIR && docker compose exec rspamd-mailcow rspamadm dkim_keygen -s dkim -d tudominio.com"
echo ""
