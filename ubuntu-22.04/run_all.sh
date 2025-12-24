#!/bin/bash

# =============================================================================
# Script: run_all.sh
# Descripción: Ejecuta todos los scripts .sh en la carpeta 'scripts/' en orden
# =============================================================================
# Uso:
#   ./run_all.sh                    - Ejecuta todos los scripts
#   ./run_all.sh --start 02         - Inicia desde el script 02
#   ./run_all.sh --skip 01,03       - Salta los scripts 01 y 03
#   ./run_all.sh --panel coolify    - Instala Coolify en lugar de ISPConfig
#   ./run_all.sh --panel ispconfig  - Instala ISPConfig (por defecto)
#   ./run_all.sh --start 02 --skip 03 - Inicia desde 02 y salta 03
# =============================================================================

SCRIPTS_DIR="$(dirname "$0")/scripts"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Parámetros
START_FROM=""
SKIP_SCRIPTS=""
PANEL_CHOICE=""

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --start)
            START_FROM="$2"
            shift 2
            ;;
        --skip)
            SKIP_SCRIPTS="$2"
            shift 2
            ;;
        --panel)
            PANEL_CHOICE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Uso: $0 [opciones]"
            echo ""
            echo "Opciones:"
            echo "  --start <num>         Iniciar desde el script con número <num>"
            echo "  --skip <nums>         Saltar scripts (números separados por comas)"
            echo "  --panel <tipo>        Elegir panel de control: 'coolify' o 'ispconfig'"
            echo "  --help, -h            Mostrar esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  $0                         - Ejecuta todos los scripts (modo interactivo)"
            echo "  $0 --panel coolify         - Instala Coolify"
            echo "  $0 --panel ispconfig       - Instala ISPConfig"
            echo "  $0 --start 02              - Inicia desde 02_*.sh"
            echo "  $0 --skip 01,03            - Salta 01_*.sh y 03_*.sh"
            echo "  $0 --start 02 --skip 03    - Inicia desde 02 y salta 03"
            exit 0
            ;;
        *)
            echo -e "${RED}Opción desconocida: $1${NC}"
            echo "Use --help para ver las opciones disponibles"
            exit 1
            ;;
    esac
done

# =============================================================================
# Selección de Panel de Control
# =============================================================================

# Si no se especificó panel, preguntar al usuario
if [ -z "$PANEL_CHOICE" ]; then
    echo "=============================================="
    echo "  Selección de Panel de Control"
    echo "=============================================="
    echo ""
    echo "Elige el panel de control a instalar:"
    echo ""
    echo "  1) ISPConfig - Panel completo de hosting con web, mail, DNS, FTP"
    echo "  2) Coolify   - Plataforma moderna para self-hosting de aplicaciones"
    echo "  3) Ninguno   - Solo configuración básica del servidor"
    echo ""
    read -p "Ingresa tu elección (1/2/3): " CHOICE
    
    case $CHOICE in
        1)
            PANEL_CHOICE="ispconfig"
            ;;
        2)
            PANEL_CHOICE="coolify"
            ;;
        3)
            PANEL_CHOICE="none"
            ;;
        *)
            echo -e "${RED}Opción inválida. Saliendo.${NC}"
            exit 1
            ;;
    esac
fi

# Configurar scripts a saltar según la elección
case $PANEL_CHOICE in
    ispconfig)
        echo -e "${GREEN}Panel seleccionado: ISPConfig${NC}"
        echo -e "${BLUE}ISPConfig incluye su propio servidor de email${NC}"
        # Saltar Coolify y Mailcow (ISPConfig ya trae email)
        if [ -z "$SKIP_SCRIPTS" ]; then
            SKIP_SCRIPTS="06,08"
        else
            SKIP_SCRIPTS="${SKIP_SCRIPTS},06,08"
        fi
        ;;
    coolify)
        echo -e "${GREEN}Panel seleccionado: Coolify${NC}"
        # Saltar ISPConfig (Mailcow se instalará para email)
        if [ -z "$SKIP_SCRIPTS" ]; then
            SKIP_SCRIPTS="07"
        else
            SKIP_SCRIPTS="${SKIP_SCRIPTS},07"
        fi
        ;;
    none)
        echo -e "${YELLOW}No se instalará ningún panel de control${NC}"
        # Saltar ambos paneles (Mailcow se instalará para email)
        if [ -z "$SKIP_SCRIPTS" ]; then
            SKIP_SCRIPTS="06,07"
        else
            SKIP_SCRIPTS="${SKIP_SCRIPTS},06,07"
        fi
        ;;
    *)
        echo -e "${RED}Panel desconocido: $PANEL_CHOICE${NC}"
        echo "Usa 'coolify', 'ispconfig', o 'none'"
        exit 1
        ;;
esac

echo ""

# Verificar si la carpeta de scripts existe
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo -e "${RED}Error: La carpeta '$SCRIPTS_DIR' no existe.${NC}"
    echo "Creando carpeta de scripts..."
    mkdir -p "$SCRIPTS_DIR"
    echo -e "${YELLOW}Carpeta creada. Agrega tus scripts .sh en: $SCRIPTS_DIR${NC}"
    exit 1
fi

# Obtener lista de scripts ordenados
SCRIPTS=$(find "$SCRIPTS_DIR" -maxdepth 1 -name "*.sh" -type f | sort)

# Verificar si hay scripts para ejecutar
if [ -z "$SCRIPTS" ]; then
    echo -e "${YELLOW}No se encontraron scripts .sh en '$SCRIPTS_DIR'${NC}"
    exit 0
fi

# Función para verificar si un script debe ser saltado
should_skip() {
    local script_name="$1"
    local script_num=$(echo "$script_name" | grep -oP '^\d+')
    
    # Convertir lista de saltos en array
    IFS=',' read -ra SKIP_ARRAY <<< "$SKIP_SCRIPTS"
    
    for skip_num in "${SKIP_ARRAY[@]}"; do
        if [ "$script_num" = "$skip_num" ]; then
            return 0  # Sí, debe saltarse
        fi
    done
    
    return 1  # No debe saltarse
}

# Función para verificar si debe iniciar desde este script
should_start() {
    local script_name="$1"
    local script_num=$(echo "$script_name" | grep -oP '^\d+')
    
    if [ -z "$START_FROM" ]; then
        return 0  # No hay filtro de inicio, ejecutar
    fi
    
    # Comparar números
    if [ "$script_num" -ge "$START_FROM" ] 2>/dev/null; then
        return 0  # Sí, debe ejecutarse
    fi
    
    return 1  # No, aún no llega al punto de inicio
}

echo "=============================================="
echo "  Ejecutando scripts en orden"
echo "=============================================="

# Mostrar filtros activos
if [ -n "$START_FROM" ]; then
    echo -e "${BLUE}Iniciando desde: ${START_FROM}_*.sh${NC}"
fi
if [ -n "$SKIP_SCRIPTS" ]; then
    echo -e "${BLUE}Saltando scripts: $SKIP_SCRIPTS${NC}"
fi
echo ""

# Contador de scripts
TOTAL=$(echo "$SCRIPTS" | wc -l)
CURRENT=0
FAILED=0

# Ejecutar cada script en orden
SKIPPED=0
for script in $SCRIPTS; do
    CURRENT=$((CURRENT + 1))
    SCRIPT_NAME=$(basename "$script")
    
    # Verificar si debe saltarse por estar antes del punto de inicio
    if ! should_start "$SCRIPT_NAME"; then
        echo -e "${BLUE}[⊘] Saltando: $SCRIPT_NAME (antes del punto de inicio)${NC}"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    # Verificar si debe saltarse por estar en la lista de exclusión
    if should_skip "$SCRIPT_NAME"; then
        echo -e "${BLUE}[⊘] Saltando: $SCRIPT_NAME (excluido manualmente)${NC}"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    echo -e "${YELLOW}[$((CURRENT - SKIPPED))/$((TOTAL - SKIPPED))] Ejecutando: $SCRIPT_NAME${NC}"
    echo "----------------------------------------------"
    
    # Dar permisos de ejecución si no los tiene
    if [ ! -x "$script" ]; then
        chmod +x "$script"
    fi
    
    # Ejecutar el script
    if bash "$script"; then
        echo -e "${GREEN}✓ $SCRIPT_NAME completado exitosamente${NC}"
    else
        echo -e "${RED}✗ $SCRIPT_NAME falló con código de salida: $?${NC}"
        FAILED=$((FAILED + 1))
        
        # Preguntar si continuar (solo si es interactivo)
        if [ -t 0 ]; then
            read -p "¿Deseas continuar con el siguiente script? (s/n): " CONTINUE
            if [ "$CONTINUE" != "s" ] && [ "$CONTINUE" != "S" ]; then
                echo -e "${RED}Ejecución cancelada por el usuario.${NC}"
                exit 1
            fi
        fi
    fi
    
    echo ""
done

echo "=============================================="
echo "  Resumen"
echo "=============================================="
echo -e "Total de scripts: $TOTAL"
echo -e "Exitosos: ${GREEN}$((TOTAL - FAILED))${NC}"
echo -e "Fallidos: ${RED}$FAILED${NC}"
echo "=============================================="

if [ $FAILED -gt 0 ]; then
    exit 1
fi

exit 0
