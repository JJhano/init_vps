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
MAILCOW_HTTP_PORT="${MAILCOW_HTTP_PORT:-80}"
MAILCOW_HTTPS_PORT="${MAILCOW_HTTPS_PORT:-443}"
MAILCOW_USE_ALTERNATE_PORTS="${MAILCOW_USE_ALTERNATE_PORTS:-auto}"

echo "=============================================="
echo "  Instalación de Mailcow"
echo "=============================================="
echo ""
echo "Mailcow es una solución completa de servidor de email"
echo "con interfaz web, webmail, antispam y antivirus."
echo ""

# =============================================================================
# Detectar conflictos con Coolify
# =============================================================================

COOLIFY_DETECTED=false
if docker ps 2>/dev/null | grep -q coolify; then
    COOLIFY_DETECTED=true
    echo "⚠ ADVERTENCIA: Coolify detectado en ejecución"
    echo ""
fi

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

# Determinar puertos a usar
if [ "$COOLIFY_DETECTED" = true ] && [ "$MAILCOW_USE_ALTERNATE_PORTS" = "auto" ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  CONFLICTO DETECTADO: Coolify y Mailcow                       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Ambos servicios necesitan los puertos 80 y 443."
    echo ""
    echo "Opciones disponibles:"
    echo ""
    echo "  1) Usar puertos alternativos para Mailcow (8080/8443)"
    echo "     - Coolify: 80/443 (apps web)"
    echo "     - Mailcow: 8080/8443 (webmail)"
    echo "     - Requiere configurar proxy reverso después"
    echo ""
    echo "  2) Detener Coolify y usar puertos estándar (80/443)"
    echo "     - Mailcow usará los puertos estándar"
    echo "     - Coolify quedará detenido"
    echo ""
    echo "  3) Cancelar instalación"
    echo "     - Configurar manualmente más tarde"
    echo ""
    read -p "Selecciona una opción (1/2/3): " PORT_CHOICE
    
    case $PORT_CHOICE in
        1)
            echo ""
            echo "✓ Configurando puertos alternativos: 8080/8443"
            MAILCOW_HTTP_PORT=8080
            MAILCOW_HTTPS_PORT=8443
            USE_ALTERNATE_PORTS=true
            ;;
        2)
            echo ""
            echo "Deteniendo Coolify..."
            docker stop $(docker ps -q --filter "name=coolify") 2>/dev/null || true
            echo "✓ Coolify detenido"
            MAILCOW_HTTP_PORT=80
            MAILCOW_HTTPS_PORT=443
            USE_ALTERNATE_PORTS=false
            ;;
        3)
            echo ""
            echo "Instalación cancelada."
            exit 0
            ;;
        *)
            echo "Opción inválida. Instalación cancelada."
            exit 1
            ;;
    esac
elif [ "$MAILCOW_USE_ALTERNATE_PORTS" = "yes" ]; then
    echo "Configurando puertos alternativos desde .env"
    USE_ALTERNATE_PORTS=true
else
    USE_ALTERNATE_PORTS=false
fi

# Verificar puertos que se van a usar
if [ "$USE_ALTERNATE_PORTS" = true ]; then
    REQUIRED_PORTS=(25 110 143 465 587 993 995 $MAILCOW_HTTP_PORT $MAILCOW_HTTPS_PORT)
else
    REQUIRED_PORTS=(25 80 110 143 443 465 587 993 995)
fi

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
    echo "Mailcow requiere estos puertos libres."
    exit 1
fi

echo "✓ Todos los puertos necesarios están disponibles"
if [ "$USE_ALTERNATE_PORTS" = true ]; then
    echo "  HTTP: $MAILCOW_HTTP_PORT | HTTPS: $MAILCOW_HTTPS_PORT"
fi

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
    
    # Configurar puertos HTTP/HTTPS si son alternativos
    if [ "$USE_ALTERNATE_PORTS" = true ]; then
        echo "Configurando puertos alternativos: $MAILCOW_HTTP_PORT/$MAILCOW_HTTPS_PORT"
        sed -i "s/^HTTP_PORT=.*/HTTP_PORT=${MAILCOW_HTTP_PORT}/g" mailcow.conf
        sed -i "s/^HTTPS_PORT=.*/HTTPS_PORT=${MAILCOW_HTTPS_PORT}/g" mailcow.conf
        
        # Deshabilitar HTTP redirect si se usan puertos alternativos
        sed -i "s/^HTTP_BIND=.*/HTTP_BIND=0.0.0.0/g" mailcow.conf
        sed -i "s/^HTTPS_BIND=.*/HTTPS_BIND=0.0.0.0/g" mailcow.conf
    fi
    
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
    
    # Puertos web
    if [ "$USE_ALTERNATE_PORTS" = true ]; then
        ufw allow ${MAILCOW_HTTP_PORT}/tcp comment 'Mailcow HTTP'
        ufw allow ${MAILCOW_HTTPS_PORT}/tcp comment 'Mailcow HTTPS'
    else
        ufw allow 80/tcp comment 'HTTP' 2>/dev/null || true
        ufw allow 443/tcp comment 'HTTPS' 2>/dev/null || true
    fi
    
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

if [ "$USE_ALTERNATE_PORTS" = true ]; then
    echo "⚠ CONFIGURACIÓN CON PUERTOS ALTERNATIVOS ⚠"
    echo ""
    echo "Accede a la interfaz web en:"
    echo "  https://${MAILCOW_HOSTNAME}:${MAILCOW_HTTPS_PORT}"
    echo "  o https://$(hostname -I | awk '{print $1}'):${MAILCOW_HTTPS_PORT}"
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  IMPORTANTE: Configurar Proxy Reverso                         ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Mailcow está usando puertos alternativos porque Coolify usa 80/443."
    echo "Para acceso sin puertos, configura un proxy reverso:"
    echo ""
    echo "Opción 1: Usar Coolify como proxy"
    echo "  1. En Coolify, agrega un 'Proxy' personalizado"
    echo "  2. Dominio: ${MAILCOW_HOSTNAME}"
    echo "  3. Destino: http://localhost:${MAILCOW_HTTP_PORT}"
    echo ""
    echo "Opción 2: Nginx Proxy Manager (recomendado)"
    echo "  Instala: docker run -d -p 81:81 -p 80:80 -p 443:443 \\"
    echo "    --name nginx-proxy-manager jc21/nginx-proxy-manager"
    echo "  Accede a :81 y configura el proxy"
    echo ""
    echo "Configuración del proxy:"
    echo "  - Dominio: ${MAILCOW_HOSTNAME}"
    echo "  - Forward Hostname: localhost"
    echo "  - Forward Port: ${MAILCOW_HTTPS_PORT}"
    echo "  - SSL: Habilitar Let's Encrypt"
    echo ""
else
    echo "Accede a la interfaz web en:"
    echo "  https://${MAILCOW_HOSTNAME}"
    echo "  o https://$(hostname -I | awk '{print $1}')"
    echo ""
fi

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
