#!/bin/bash

# =============================================================================
# Script de Instalación de ISPConfig 3
# Ubuntu 22.04
# =============================================================================
# Basado en: https://www.howtoforge.com/ispconfig-autoinstall-debian-ubuntu/
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
ISPCONFIG_USE_PHP="${ISPCONFIG_USE_PHP:-no}"
ISPCONFIG_USE_WEBSERVER="${ISPCONFIG_USE_WEBSERVER:-nginx}"
ISPCONFIG_USE_FTPSERVER="${ISPCONFIG_USE_FTPSERVER:-pureftpd}"
ISPCONFIG_MYSQL_ROOT_PASSWORD="${ISPCONFIG_MYSQL_ROOT_PASSWORD:-}"
ISPCONFIG_ADMIN_PASSWORD="${ISPCONFIG_ADMIN_PASSWORD:-}"
ISPCONFIG_HOSTNAME="${ISPCONFIG_HOSTNAME:-server1.example.com}"
ISPCONFIG_SSL_CERT_COUNTRY="${ISPCONFIG_SSL_CERT_COUNTRY:-US}"
ISPCONFIG_SSL_CERT_STATE="${ISPCONFIG_SSL_CERT_STATE:-California}"
ISPCONFIG_SSL_CERT_LOCALITY="${ISPCONFIG_SSL_CERT_LOCALITY:-Los Angeles}"
ISPCONFIG_SSL_CERT_ORGANIZATION="${ISPCONFIG_SSL_CERT_ORGANIZATION:-MyCompany}"

echo "=============================================="
echo "  Instalación de ISPConfig 3"
echo "=============================================="
echo ""
echo "Configuración:"
echo "  - Servidor Web: $ISPCONFIG_USE_WEBSERVER"
echo "  - PHP: $ISPCONFIG_USE_PHP"
echo "  - FTP: $ISPCONFIG_USE_FTPSERVER"
echo "  - Hostname: $ISPCONFIG_HOSTNAME"
echo ""

# =============================================================================
# Prerequisitos
# =============================================================================

echo "[1/4] Instalando prerequisitos..."

# Actualizar sistema
apt update
apt upgrade -y

# Instalar paquetes necesarios
apt install -y wget curl git

# Configurar hostname si fue especificado
if [ -n "$ISPCONFIG_HOSTNAME" ] && [ "$ISPCONFIG_HOSTNAME" != "server1.example.com" ]; then
    echo "Configurando hostname: $ISPCONFIG_HOSTNAME"
    hostnamectl set-hostname "$ISPCONFIG_HOSTNAME"
    
    # Actualizar /etc/hosts
    HOST_IP=$(hostname -I | awk '{print $1}')
    if ! grep -q "$ISPCONFIG_HOSTNAME" /etc/hosts; then
        echo "$HOST_IP $ISPCONFIG_HOSTNAME $(hostname -s)" >> /etc/hosts
    fi
fi

# =============================================================================
# Descargar ISPConfig Auto-Installer
# =============================================================================

echo ""
echo "[2/4] Descargando ISPConfig Auto-Installer..."

cd /tmp
if [ -d "ispconfig-autoinstaller" ]; then
    rm -rf ispconfig-autoinstaller
fi

git clone https://github.com/ispconfig/ispconfig-autoinstaller.git
cd ispconfig-autoinstaller

# =============================================================================
# Preparar archivo de configuración
# =============================================================================

echo ""
echo "[3/4] Preparando configuración..."

# Crear archivo de configuración automática
cat > autoinstall.ini << EOF
[install]
language=en
install_mode=standard

[server]
hostname=${ISPCONFIG_HOSTNAME}

[web]
webserver=${ISPCONFIG_USE_WEBSERVER}
php_versions=${ISPCONFIG_USE_PHP}

[ftp]
ftpserver=${ISPCONFIG_USE_FTPSERVER}

[ssl]
ssl_cert_country=${ISPCONFIG_SSL_CERT_COUNTRY}
ssl_cert_state=${ISPCONFIG_SSL_CERT_STATE}
ssl_cert_locality=${ISPCONFIG_SSL_CERT_LOCALITY}
ssl_cert_organisation=${ISPCONFIG_SSL_CERT_ORGANIZATION}
ssl_cert_organisation_unit=IT
ssl_cert_common_name=${ISPCONFIG_HOSTNAME}
EOF

# Agregar contraseñas si fueron proporcionadas
if [ -n "$ISPCONFIG_MYSQL_ROOT_PASSWORD" ]; then
    cat >> autoinstall.ini << EOF

[mysql]
mysql_root_password=${ISPCONFIG_MYSQL_ROOT_PASSWORD}
EOF
fi

if [ -n "$ISPCONFIG_ADMIN_PASSWORD" ]; then
    cat >> autoinstall.ini << EOF

[ispconfig]
admin_password=${ISPCONFIG_ADMIN_PASSWORD}
EOF
fi

# =============================================================================
# Ejecutar instalación
# =============================================================================

echo ""
echo "[4/4] Ejecutando instalación de ISPConfig..."
echo ""
echo "NOTA: Este proceso puede tomar entre 30-60 minutos"
echo "      dependiendo de la velocidad de tu servidor."
echo ""

# Si no hay contraseñas definidas, ejecutar en modo interactivo
if [ -z "$ISPCONFIG_MYSQL_ROOT_PASSWORD" ] || [ -z "$ISPCONFIG_ADMIN_PASSWORD" ]; then
    echo "ATENCIÓN: Algunas contraseñas no están definidas en .env"
    echo "          La instalación será interactiva."
    echo ""
    sleep 3
    php -q install.php
else
    # Instalación desatendida con archivo de configuración
    php -q install.php --autoinstall=autoinstall.ini
fi

# =============================================================================
# Finalización
# =============================================================================

echo ""
echo "=============================================="
echo "  ISPConfig 3 instalado correctamente!"
echo "=============================================="
echo ""
echo "Accede al panel de control en:"
echo "  https://$(hostname -I | awk '{print $1}'):8080"
echo "  o"
echo "  https://${ISPCONFIG_HOSTNAME}:8080"
echo ""
echo "Credenciales por defecto (si no se especificaron):"
echo "  Usuario: admin"
echo "  Contraseña: admin (cámbiala inmediatamente)"
echo ""
echo "IMPORTANTE: Recuerda abrir el puerto 8080 en el firewall:"
echo "  ufw allow 8080/tcp"
echo ""
echo "Servicios instalados:"
echo "  - Servidor Web: $ISPCONFIG_USE_WEBSERVER"
echo "  - PHP: $ISPCONFIG_USE_PHP"
echo "  - MySQL/MariaDB"
echo "  - FTP: $ISPCONFIG_USE_FTPSERVER"
echo "  - Mail Server (Postfix/Dovecot)"
echo "  - DNS (BIND)"
echo ""
echo "Documentación: https://www.ispconfig.org/documentation/"
echo ""
