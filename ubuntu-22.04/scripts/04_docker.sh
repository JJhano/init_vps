#!/bin/bash

# =============================================================================
# Script de Instalación de Docker
# Ubuntu 22.04
# =============================================================================
# Documentación: https://docs.docker.com/engine/install/ubuntu/
# =============================================================================

set -e

echo "=============================================="
echo "  Instalación de Docker"
echo "=============================================="
echo ""

# =============================================================================
# Prerequisitos
# =============================================================================

echo "[1/4] Instalando prerequisitos..."

# Actualizar índice de paquetes
apt update

# Instalar paquetes necesarios
apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# =============================================================================
# Añadir repositorio oficial de Docker
# =============================================================================

echo ""
echo "[2/4] Configurando repositorio de Docker..."

# Crear directorio para claves GPG
install -m 0755 -d /etc/apt/keyrings

# Añadir clave GPG oficial de Docker
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "Clave GPG de Docker añadida"
else
    echo "Clave GPG de Docker ya existe"
fi

# Añadir repositorio de Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Repositorio de Docker configurado"

# =============================================================================
# Instalar Docker Engine
# =============================================================================

echo ""
echo "[3/4] Instalando Docker Engine..."

# Actualizar índice de paquetes
apt update

# Instalar Docker Engine, CLI, containerd y plugins
apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo "Docker instalado correctamente"

# =============================================================================
# Configuración post-instalación
# =============================================================================

echo ""
echo "[4/4] Configurando Docker..."

# Iniciar y habilitar Docker
systemctl start docker
systemctl enable docker

# Verificar instalación
docker --version
docker compose version

# Probar Docker
echo ""
echo "Probando instalación de Docker..."
if docker run --rm hello-world > /dev/null 2>&1; then
    echo "✓ Docker funciona correctamente"
else
    echo "⚠ Advertencia: No se pudo ejecutar el contenedor de prueba"
fi

# =============================================================================
# Información adicional
# =============================================================================

echo ""
echo "=============================================="
echo "  Docker instalado correctamente!"
echo "=============================================="
echo ""
echo "Versiones instaladas:"
docker --version
docker compose version
echo ""
echo "Comandos útiles:"
echo "  - Ver contenedores: docker ps"
echo "  - Ver imágenes: docker images"
echo "  - Logs: docker logs <container>"
echo "  - Ejecutar contenedor: docker run <image>"
echo ""
echo "NOTA: Para usar Docker sin sudo, añade tu usuario al grupo docker:"
echo "  usermod -aG docker \$USER"
echo "  (requiere cerrar sesión y volver a iniciar)"
echo ""
echo "Documentación: https://docs.docker.com/"
echo ""
