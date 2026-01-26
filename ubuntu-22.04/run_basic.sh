#!/bin/bash

# =============================================================================
# Script: run_basic.sh
# Descripción: Ejecuta configuraciones básicas de VPS (update, SSH, UFW, fail2ban)
#              y pregunta si desea instalar Docker
# =============================================================================
# Uso:
#   ./run_basic.sh
# =============================================================================

SCRIPTS_DIR="$(dirname "$0")/scripts"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Banner
echo -e "${BLUE}"
echo "================================================================"
echo "      Configuración Básica de VPS - Ubuntu 22.04"
echo "================================================================"
echo -e "${NC}"
echo ""
echo "Este script ejecutará las siguientes configuraciones:"
echo "  1. Actualización del sistema"
echo "  2. Configuración de SSH"
echo "  3. Configuración de UFW (firewall)"
echo "  4. Instalación de Fail2ban"
echo "  + Opción de instalar Docker"
echo ""
echo -e "${YELLOW}IMPORTANTE: Este script requiere privilegios de root${NC}"
echo ""
read -p "¿Desea continuar? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    echo "Operación cancelada."
    exit 0
fi

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: Este script debe ejecutarse como root${NC}"
   exit 1
fi

# Verificar que existe la carpeta de scripts
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo -e "${RED}Error: No se encuentra la carpeta de scripts: $SCRIPTS_DIR${NC}"
    exit 1
fi

# Función para ejecutar un script
run_script() {
    local script_num=$1
    local script_name=$2
    local script_path="${SCRIPTS_DIR}/${script_num}_${script_name}.sh"
    
    if [ ! -f "$script_path" ]; then
        echo -e "${RED}Error: No se encuentra el script: $script_path${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${GREEN}Ejecutando: ${script_num}_${script_name}.sh${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
    
    chmod +x "$script_path"
    
    if bash "$script_path"; then
        echo ""
        echo -e "${GREEN}✓ Script ${script_num}_${script_name}.sh completado exitosamente${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}✗ Error al ejecutar ${script_num}_${script_name}.sh${NC}"
        return 1
    fi
}

# Array de scripts básicos a ejecutar
BASIC_SCRIPTS=(
    "01:update"
    "02:ssh"
    "03:ufw"
    "04:fail2ban"
)

# Ejecutar scripts básicos
echo ""
echo -e "${BLUE}Iniciando configuración básica...${NC}"
echo ""

FAILED_SCRIPTS=()

for script_info in "${BASIC_SCRIPTS[@]}"; do
    IFS=':' read -r num name <<< "$script_info"
    
    if ! run_script "$num" "$name"; then
        FAILED_SCRIPTS+=("${num}_${name}.sh")
        echo ""
        echo -e "${YELLOW}¿Desea continuar a pesar del error? (s/n): ${NC}"
        read -p "" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
            echo -e "${RED}Ejecución detenida por el usuario.${NC}"
            exit 1
        fi
    fi
done

# Preguntar por Docker
echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${YELLOW}¿Desea instalar Docker? (s/n): ${NC}"
read -p "" -n 1 -r
echo
echo -e "${BLUE}================================================================${NC}"

if [[ $REPLY =~ ^[SsYy]$ ]]; then
    if ! run_script "05" "docker"; then
        FAILED_SCRIPTS+=("05_docker.sh")
        echo -e "${YELLOW}Docker no se instaló correctamente${NC}"
    fi
fi

# Resumen final
echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}      Configuración Básica Completada${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

if [ ${#FAILED_SCRIPTS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ Todos los scripts se ejecutaron exitosamente${NC}"
else
    echo -e "${YELLOW}⚠ Los siguientes scripts tuvieron errores:${NC}"
    for script in "${FAILED_SCRIPTS[@]}"; do
        echo -e "  ${RED}✗${NC} $script"
    done
fi

echo ""
echo -e "${YELLOW}Recomendaciones:${NC}"
echo "  1. Revisar los logs de cada servicio"
echo "  2. Probar la conexión SSH antes de cerrar la sesión actual"
echo "  3. Verificar que el firewall permite las conexiones necesarias"
echo ""
echo -e "${GREEN}Para instalar servicios adicionales, use:${NC}"
echo "  - ./run_all.sh --start 06  (Para instalar servicios desde el script 06)"
echo ""

exit 0
