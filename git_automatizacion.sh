#!/bin/bash

#=============================================================================
# Script: git_automatizacion
# Descripción: Script profesional avanzado para automatizar operaciones de Git y GitHub
# Autor: Sistema de Automatización Git Avanzado
# Versión: 2.0.0
# Fecha: $(date +"%Y-%m-%d")
#=============================================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Variables globales
SCRIPT_NAME="git_automatizacion"
VERSION="2.0.0"
CONFIG_DIR="$HOME/.git_automation"
CONFIG_FILE="$CONFIG_DIR/config.json"
REPOS_FILE="$CONFIG_DIR/repositories.json"
LOG_FILE="$CONFIG_DIR/automation.log"
BACKUP_DIR="$CONFIG_DIR/backups"

# Funciones de utilidad
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                     GIT AUTOMATION TOOL ADVANCED                  ║"
    echo "║                            v${VERSION}                                ║"
    echo "║                    🚀 Automatización Profesional 🚀                ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${GRAY}$(date '+%Y-%m-%d %H:%M:%S') - Sesión iniciada${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}${BOLD}✓${NC} ${GREEN}$1${NC}"
    log_message "SUCCESS" "$1"
}

print_error() {
    echo -e "${RED}${BOLD}✗${NC} ${RED}Error: $1${NC}"
    log_message "ERROR" "$1"
}

print_warning() {
    echo -e "${YELLOW}${BOLD}⚠${NC} ${YELLOW}Advertencia: $1${NC}"
    log_message "WARNING" "$1"
}

print_info() {
    echo -e "${BLUE}${BOLD}ℹ${NC} ${BLUE}$1${NC}"
    log_message "INFO" "$1"
}

print_question() {
    echo -e "${PURPLE}${BOLD}?${NC} ${PURPLE}$1${NC}"
}

print_separator() {
    echo -e "${GRAY}${'─' * 70}${NC}"
}

# Sistema de logging mejorado
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Función para mostrar progress bar
show_progress() {
    local duration=$1
    local message=$2
    local progress=0
    local bar_length=50

    echo -ne "${CYAN}$message: ${NC}"
    
    while [ $progress -le 100 ]; do
        local filled=$((progress * bar_length / 100))
        local empty=$((bar_length - filled))
        
        printf "\r${CYAN}$message: ${NC}["
        printf "%*s" $filled | tr ' ' '█'
        printf "%*s" $empty | tr ' ' '░'
        printf "] %d%%" $progress
        
        sleep $(echo "$duration / 100" | bc -l 2>/dev/null || echo "0.01")
        progress=$((progress + 1))
    done
    echo ""
}

# Función para crear backup automático
create_backup() {
    local repo_path="$1"
    local backup_name="backup_$(basename "$repo_path")_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
    
    print_info "Creando backup de seguridad..."
    if tar -czf "$backup_path.tar.gz" -C "$(dirname "$repo_path")" "$(basename "$repo_path")" 2>/dev/null; then
        print_success "Backup creado: $backup_path.tar.gz"
        
        # Limpiar backups antiguos (mantener solo los últimos 5)
        cleanup_old_backups
        return 0
    else
        print_warning "No se pudo crear el backup"
        return 1
    fi
}

# Función para limpiar backups antiguos
cleanup_old_backups() {
    local backup_count=$(find "$BACKUP_DIR" -name "backup_*.tar.gz" | wc -l)
    if [ "$backup_count" -gt 5 ]; then
        print_info "Limpiando backups antiguos..."
        find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f -printf '%T@ %p\n' | sort -n | head -n -5 | cut -d' ' -f2- | xargs rm -f
        print_success "Backups antiguos eliminados"
    fi
}

# Función para mostrar estadísticas del repositorio
show_repo_stats() {
    local repo_path="$1"
    
    if [ ! -d "$repo_path/.git" ]; then
        return 1
    fi
    
    cd "$repo_path" || return 1
    
    echo -e "${BOLD}${CYAN}📊 ESTADÍSTICAS DEL REPOSITORIO${NC}"
    print_separator
    
    # Información básica
    local repo_name=$(basename "$repo_path")
    local current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "N/A")
    local remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "No configurado")
    local last_commit=$(git log -1 --format="%h - %s (%ar)" 2>/dev/null || echo "No hay commits")
    
    echo -e "${WHITE}Repositorio:${NC} $repo_name"
    echo -e "${WHITE}Rama actual:${NC} $current_branch"
    echo -e "${WHITE}URL remota:${NC} $remote_url"
    echo -e "${WHITE}Último commit:${NC} $last_commit"
    
    # Estadísticas de archivos
    local total_files=$(find . -type f -not -path "./.git/*" | wc -l)
    local modified_files=$(git status --porcelain 2>/dev/null | wc -l)
    local total_commits=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    local contributors=$(git shortlog -sn --all | wc -l 2>/dev/null || echo "0")
    
    echo -e "${WHITE}Total de archivos:${NC} $total_files"
    echo -e "${WHITE}Archivos modificados:${NC} $modified_files"
    echo -e "${WHITE}Total de commits:${NC} $total_commits"
    echo -e "${WHITE}Colaboradores:${NC} $contributors"
    
    # Tamaño del repositorio
    local repo_size=$(du -sh . 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "${WHITE}Tamaño del repositorio:${NC} $repo_size"
    
    print_separator
}

# Función para mostrar ayuda mejorada
show_help() {
    print_banner
    cat << EOF
${CYAN}${BOLD}USO: $SCRIPT_NAME [OPCIONES]${NC}

${WHITE}${BOLD}OPCIONES PRINCIPALES:${NC}
  ${YELLOW}-h, --help${NC}                 Mostrar esta ayuda detallada
  ${YELLOW}-v, --version${NC}             Mostrar información de versión
  ${YELLOW}-S, --subir${NC}               Subir archivos/cambios al repositorio
  ${YELLOW}-C, --clonar${NC}              Clonar repositorio existente
  ${YELLOW}-I, --init${NC}                Inicializar nuevo repositorio
  ${YELLOW}-U, --update${NC}              Actualizar repositorio existente
  ${YELLOW}-R, --registrar${NC}           Registrar nuevo repositorio en configuración
  ${YELLOW}-L, --listar${NC}              Listar repositorios configurados
  ${YELLOW}--config${NC}                  Configurar credenciales globales
  ${YELLOW}--stats${NC}                   Mostrar estadísticas del repositorio
  ${YELLOW}--backup${NC}                  Crear backup del repositorio

${WHITE}${BOLD}OPCIONES DE SUBIDA (-S):${NC}
  ${CYAN}--path <ruta>${NC}             Ruta del archivo o directorio a subir
  ${CYAN}--message <mensaje>${NC}       Mensaje de commit personalizado
  ${CYAN}--branch <rama>${NC}           Rama específica (default: main/master)
  ${CYAN}--force${NC}                   Forzar push (usar con cuidado)
  ${CYAN}--auto-backup${NC}             Crear backup automático antes de subir

${WHITE}${BOLD}OPCIONES DE INICIALIZACIÓN (-I):${NC}
  ${CYAN}--name <nombre>${NC}           Nombre del repositorio
  ${CYAN}--description <desc>${NC}      Descripción del repositorio
  ${CYAN}--private${NC}                 Crear repositorio privado
  ${CYAN}--public${NC}                  Crear repositorio público (default)
  ${CYAN}--template <tipo>${NC}         Usar plantilla (node, python, react, etc.)

${WHITE}${BOLD}OPCIONES AVANZADAS:${NC}
  ${CYAN}--interactive${NC}             Modo interactivo con menú
  ${CYAN}--log${NC}                     Mostrar logs de actividad
  ${CYAN}--cleanup${NC}                 Limpiar archivos temporales y backups antiguos
  ${CYAN}--export-config${NC}           Exportar configuración
  ${CYAN}--import-config${NC}           Importar configuración

${WHITE}${BOLD}EJEMPLOS DE USO:${NC}
  ${GREEN}# Configurar por primera vez${NC}
  $SCRIPT_NAME --config

  ${GREEN}# Modo interactivo (NUEVO)${NC}
  $SCRIPT_NAME --interactive

  ${GREEN}# Crear proyecto con plantilla (NUEVO)${NC}
  $SCRIPT_NAME -I --name "mi-app" --template react --path ./mi-app

  ${GREEN}# Subir con backup automático${NC}
  $SCRIPT_NAME -S --path . --auto-backup --message "Actualización importante"

  ${GREEN}# Ver estadísticas del repositorio${NC}
  $SCRIPT_NAME --stats --path ./mi-proyecto

  ${GREEN}# Crear backup manual${NC}
  $SCRIPT_NAME --backup --path ./mi-proyecto

${WHITE}${BOLD}PLANTILLAS DISPONIBLES:${NC}
  ${PURPLE}• node${NC}        - Proyecto Node.js con package.json
  ${PURPLE}• python${NC}      - Proyecto Python con requirements.txt
  ${PURPLE}• react${NC}       - Aplicación React con estructura básica
  ${PURPLE}• vue${NC}         - Aplicación Vue.js
  ${PURPLE}• angular${NC}     - Proyecto Angular
  ${PURPLE}• flask${NC}       - API Flask
  ${PURPLE}• django${NC}      - Proyecto Django
  ${PURPLE}• basic${NC}       - Estructura básica con README

EOF
}

# Función para verificar dependencias mejorada
check_dependencies() {
    local deps=("git" "curl" "jq" "tar" "bc")
    local missing=()
    local optional_missing=()

    print_info "Verificando dependencias..."

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            if [[ "$dep" == "bc" ]]; then
                optional_missing+=("$dep")
            else
                missing+=("$dep")
            fi
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Dependencias críticas faltantes: ${missing[*]}"
        echo ""
        echo -e "${YELLOW}Instala las dependencias según tu distribución:${NC}"
        echo -e "${CYAN}Ubuntu/Debian:${NC} sudo apt-get install git curl jq tar bc"
        echo -e "${CYAN}CentOS/RHEL:${NC}   sudo yum install git curl jq tar bc"
        echo -e "${CYAN}Fedora:${NC}        sudo dnf install git curl jq tar bc"
        echo -e "${CYAN}Arch:${NC}          sudo pacman -S git curl jq tar bc"
        echo -e "${CYAN}openSUSE:${NC}      sudo zypper install git curl jq tar bc"
        echo -e "${CYAN}Alpine:${NC}        apk add git curl jq tar bc"
        exit 1
    fi

    if [ ${#optional_missing[@]} -ne 0 ]; then
        print_warning "Dependencias opcionales faltantes: ${optional_missing[*]}"
        print_info "Algunas funciones avanzadas podrían no estar disponibles"
    fi

    print_success "Dependencias verificadas correctamente"
}

# Función para crear directorios de configuración mejorada
setup_config_dir() {
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        mkdir -p "$BACKUP_DIR"
        touch "$LOG_FILE"
        print_success "Estructura de configuración creada: $CONFIG_DIR"
    fi
}

# Función para configurar credenciales mejorada
configure_credentials() {
    print_banner
    echo -e "${WHITE}${BOLD}=== CONFIGURACIÓN DE CREDENCIALES GLOBALES ===${NC}"
    echo ""

    # Verificar si ya existe configuración
    if [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
        print_warning "Ya existe una configuración."
        print_question "¿Deseas actualizarla? (y/n)"
        read -r response
        if [[ ! "$response" =~ ^[yY]$ ]]; then
            return 0
        fi
    fi

    # Verificar conectividad a GitHub
    print_info "Verificando conectividad con GitHub..."
    if ! curl -s --connect-timeout 5 https://api.github.com > /dev/null; then
        print_error "No se puede conectar a GitHub. Verifica tu conexión a internet."
        return 1
    fi
    print_success "Conectividad verificada"

    # Solicitar información del usuario con validación
    while true; do
        print_question "Ingresa tu nombre de usuario de GitHub:"
        read -r github_user
        if [[ -n "$github_user" && "$github_user" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            break
        else
            print_error "Nombre de usuario inválido. Solo se permiten letras, números, guiones y guiones bajos."
        fi
    done
    
    while true; do
        print_question "Ingresa tu email de GitHub:"
        read -r github_email
        if [[ "$github_email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
            break
        else
            print_error "Email inválido. Ingresa un email válido."
        fi
    done
    
    print_question "Ingresa tu token de acceso personal de GitHub:"
    echo -e "${YELLOW}💡 Tip: Puedes generarlo en: https://github.com/settings/tokens${NC}"
    echo -e "${YELLOW}   Permisos necesarios: repo, user, delete_repo${NC}"
    read -rs github_token
    echo ""

    # Verificar token
    print_info "Verificando token de acceso..."
    if ! curl -s -H "Authorization: token $github_token" https://api.github.com/user > /dev/null; then
        print_error "Token de acceso inválido. Verifica que el token sea correcto."
        return 1
    fi
    print_success "Token verificado correctamente"

    print_question "Ingresa tu nombre completo para los commits:"
    read -r full_name

    # Configurar git globalmente
    git config --global user.name "$full_name"
    git config --global user.email "$github_email"
    git config --global init.defaultBranch main

    # Guardar configuración con metadatos adicionales
    cat > "$CONFIG_FILE" << EOF
{
    "github_user": "$github_user",
    "github_email": "$github_email",
    "github_token": "$github_token",
    "full_name": "$full_name",
    "configured_at": "$(date -Iseconds)",
    "version": "$VERSION",
    "auto_backup": true,
    "default_branch": "main"
}
EOF

    print_success "Configuración guardada exitosamente"
    print_info "Git configurado globalmente con tus credenciales"
}

# Función para cargar configuración mejorada
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "No se encontró configuración. Ejecuta: $SCRIPT_NAME --config"
        exit 1
    fi

    GITHUB_USER=$(jq -r '.github_user' "$CONFIG_FILE" 2>/dev/null)
    GITHUB_EMAIL=$(jq -r '.github_email' "$CONFIG_FILE" 2>/dev/null)
    GITHUB_TOKEN=$(jq -r '.github_token' "$CONFIG_FILE" 2>/dev/null)
    FULL_NAME=$(jq -r '.full_name' "$CONFIG_FILE" 2>/dev/null)
    AUTO_BACKUP=$(jq -r '.auto_backup // true' "$CONFIG_FILE" 2>/dev/null)

    if [ "$GITHUB_USER" = "null" ] || [ "$GITHUB_TOKEN" = "null" ] || [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_TOKEN" ]; then
        print_error "Configuración inválida o corrupta. Ejecuta: $SCRIPT_NAME --config"
        exit 1
    fi
}

# Función para crear plantillas de proyecto
create_project_template() {
    local template_type="$1"
    local project_path="$2"
    local project_name="$3"

    print_info "Creando plantilla de proyecto: $template_type"

    case "$template_type" in
        "node")
            cat > "$project_path/package.json" << EOF
{
  "name": "$project_name",
  "version": "1.0.0",
  "description": "Proyecto Node.js creado con Git Automation Tool",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "node index.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": [],
  "author": "$FULL_NAME",
  "license": "MIT"
}
EOF
            cat > "$project_path/index.js" << EOF
console.log('¡Hola mundo desde $project_name!');

// Tu código aquí
const main = () => {
    console.log('Aplicación Node.js iniciada correctamente');
};

main();
EOF
            cat > "$project_path/.gitignore" << EOF
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
dist/
build/
EOF
            ;;
        "python")
            cat > "$project_path/main.py" << EOF
#!/usr/bin/env python3
"""
$project_name
Proyecto Python creado con Git Automation Tool
Autor: $FULL_NAME
"""

def main():
    print("¡Hola mundo desde $project_name!")
    print("Aplicación Python iniciada correctamente")

if __name__ == "__main__":
    main()
EOF
            cat > "$project_path/requirements.txt" << EOF
# Dependencias del proyecto $project_name
# Ejemplo: requests>=2.25.1
EOF
            cat > "$project_path/.gitignore" << EOF
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
venv/
ENV/
env/
.env
EOF
            ;;
        "react")
            cat > "$project_path/package.json" << EOF
{
  "name": "$project_name",
  "version": "0.1.0",
  "private": true,
  "description": "Aplicación React creada con Git Automation Tool",
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  },
  "author": "$FULL_NAME"
}
EOF
            mkdir -p "$project_path/src" "$project_path/public"
            cat > "$project_path/src/App.js" << EOF
import React from 'react';
import './App.css';

function App() {
  return (
    <div className="App">
      <header className="App-header">
        <h1>¡Bienvenido a $project_name!</h1>
        <p>Aplicación React creada con Git Automation Tool</p>
      </header>
    </div>
  );
}

export default App;
EOF
            cat > "$project_path/src/index.js" << EOF
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF
            cat > "$project_path/public/index.html" << EOF
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>$project_name</title>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
EOF
            ;;
        *)
            print_warning "Plantilla '$template_type' no reconocida, usando plantilla básica"
            ;;
    esac

    print_success "Plantilla '$template_type' creada exitosamente"
}

# Función para modo interactivo (NUEVA FUNCIONALIDAD)
interactive_mode() {
    while true; do
        print_banner
        echo -e "${WHITE}${BOLD}=== MENÚ INTERACTIVO ===${NC}"
        echo ""
        echo -e "${CYAN}1.${NC} Configurar credenciales"
        echo -e "${CYAN}2.${NC} Registrar nuevo repositorio"
        echo -e "${CYAN}3.${NC} Inicializar proyecto nuevo"
        echo -e "${CYAN}4.${NC} Subir cambios"
        echo -e "${CYAN}5.${NC} Actualizar repositorio"
        echo -e "${CYAN}6.${NC} Clonar repositorio"
        echo -e "${CYAN}7.${NC} Ver estadísticas"
        echo -e "${CYAN}8.${NC} Crear backup"
        echo -e "${CYAN}9.${NC} Listar repositorios"
        echo -e "${CYAN}10.${NC} Ver logs"
        echo -e "${CYAN}0.${NC} Salir"
        echo ""
        print_question "Selecciona una opción (0-10):"
        
        read -r choice
        echo ""
        
        case $choice in
            1)
                configure_credentials
                ;;
            2)
                load_config
                register_repository
                ;;
            3)
                load_config
                interactive_init_repository
                ;;
            4)
                load_config
                interactive_upload_changes
                ;;
            5)
                load_config
                interactive_update_repository
                ;;
            6)
                load_config
                clone_repository
                ;;
            7)
                interactive_show_stats
                ;;
            8)
                interactive_create_backup
                ;;
            9)
                list_repositories
                ;;
            10)
                show_logs
                ;;
            0)
                print_info "¡Hasta luego!"
                exit 0
                ;;
            *)
                print_error "Opción inválida. Por favor, selecciona un número del 0 al 10."
                ;;
        esac
        
        echo ""
        print_question "Presiona Enter para continuar..."
        read -r
    done
}

# Funciones auxiliares para modo interactivo
interactive_init_repository() {
    print_question "Nombre del repositorio:"
    read -r repo_name
    
    print_question "Ruta del proyecto (Enter para directorio actual):"
    read -r repo_path
    repo_path=${repo_path:-$(pwd)}
    
    print_question "Descripción del proyecto:"
    read -r description
    
    print_question "¿Repositorio privado? (y/n, default: n):"
    read -r is_private
    is_private=${is_private:-n}
    
    print_question "¿Usar plantilla? (node/python/react/basic, Enter para ninguna):"
    read -r template
    
    local privacy="false"
    [[ "$is_private" =~ ^[yY]$ ]] && privacy="true"
    
    initialize_repository "$repo_name" "$repo_path" "$description" "$privacy" "$template"
}

interactive_upload_changes() {
    print_question "Ruta del archivo/directorio (Enter para directorio actual):"
    read -r target_path
    target_path=${target_path:-$(pwd)}
    
    print_question "Mensaje de commit:"
    read -r commit_message
    
    print_question "¿Crear backup antes de subir? (y/n, default: y):"
    read -r create_backup_choice
    create_backup_choice=${create_backup_choice:-y}
    
    local auto_backup="false"
    [[ "$create_backup_choice" =~ ^[yY]$ ]] && auto_backup="true"
    
    upload_changes "$target_path" "$commit_message" "" "false" "$auto_backup"
}

interactive_update_repository() {
    print_question "Ruta del repositorio (Enter para directorio actual):"
    read -r repo_path
    repo_path=${repo_path:-$(pwd)}
    
    update_repository "$repo_path"
}

interactive_show_stats() {
    print_question "Ruta del repositorio (Enter para directorio actual):"
    read -r repo_path
    repo_path=${repo_path:-$(pwd)}
    
    show_repo_stats "$repo_path"
}

interactive_create_backup() {
    print_question "Ruta del repositorio a respaldar (Enter para directorio actual):"
    read -r repo_path
    repo_path=${repo_path:-$(pwd)}
    
    create_backup "$repo_path"
}

# Función para mostrar logs (NUEVA FUNCIONALIDAD)
show_logs() {
    print_banner
    echo -e "${WHITE}${BOLD}=== LOGS DE ACTIVIDAD ===${NC}"
    echo ""
    
    if [ ! -f "$LOG_FILE" ]; then
        print_warning "No se encontraron logs"
        return 0
    fi
    
    local log_lines=$(wc -l < "$LOG_FILE")
    print_info "Total de entradas en el log: $log_lines"
    echo ""
    
    print_question "¿Cuántas líneas mostrar? (Enter para últimas 20):"
    read -r lines
    lines=${lines:-20}
    
    echo -e "${GRAY}"
    tail -n "$lines" "$LOG_FILE" | while IFS= read -r line; do
        if [[ "$line" == *"ERROR"* ]]; then
            echo -e "${RED}$line${GRAY}"
        elif [[ "$line" == *"WARNING"* ]]; then
            echo -e "${YELLOW}$line${GRAY}"
        elif [[ "$line" == *"SUCCESS"* ]]; then
            echo -e "${GREEN}$line${GRAY}"
        else
            echo "$line"
        fi
    done
    echo -e "${NC}"
}

# Función para registrar repositorio mejorada
register_repository() {
    print_banner
    echo -e "${WHITE}${BOLD}=== REGISTRO DE NUEVO REPOSITORIO ===${NC}"
    echo ""

    print_question "Ingresa el nombre del repositorio:"
    read -r repo_name
    
    # Validar nombre del repositorio
    if [[ ! "$repo_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        print_error "Nombre de repositorio inválido. Solo se permiten letras, números, puntos, guiones y guiones bajos."
        return 1
    fi
    
    print_question "Ingresa la URL del repositorio (opcional, si ya existe):"
    read -r repo_url
    
    print_question "Ingresa la ruta local del proyecto:"
    read -r local_path
    
    print_question "Ingresa una descripción del proyecto:"
    read -r description
    
    print_question "¿Es un repositorio privado? (y/n):"
    read -r is_private
    
    # Validar ruta local
    if [ ! -d "$local_path" ]; then
        print_error "La ruta especificada no existe: $local_path"
        return 1
    fi

    # Crear archivo de repositorios si no existe
    if [ ! -f "$REPOS_FILE" ]; then
        echo "[]" > "$REPOS_FILE"
    fi

    # Verificar si el repositorio ya está registrado
    if jq -e --arg name "$repo_name" '.[] | select(.name == $name)' "$REPOS_FILE" &> /dev/null; then
        print_warning "El repositorio '$repo_name' ya está registrado"
        return 1
    fi

    # Agregar repositorio al archivo
    local privacy="public"
    [[ "$is_private" =~ ^[yY]$ ]] && privacy="private"

    local temp_file=$(mktemp)
    jq --arg name "$repo_name" \
       --arg url "$repo_url" \
       --arg path "$local_path" \
       --arg desc "$description" \
       --arg privacy "$privacy" \
       --arg created "$(date -Iseconds)" \
       '. += [{
           "name": $name,
           "url": $url,
           "local_path": $path,
           "description": $desc,
           "private": $privacy,
           "created_at": $created,
           "last_updated": $created
       }]' "$REPOS_FILE" > "$temp_file"

    mv "$temp_file" "$REPOS_FILE"
    print_success "Repositorio '$repo_name' registrado exitosamente"
}

# Función para listar repositorios mejorada
list_repositories() {
    print_banner
    echo -e "${WHITE}${BOLD}=== REPOSITORIOS CONFIGURADOS ===${NC}"
    echo ""

    if [ ! -f "$REPOS_FILE" ] || [ ! -s "$REPOS_FILE" ]; then
        print_warning "No hay repositorios registrados"
        print_info "Usa '$SCRIPT_NAME -R' para registrar tu primer repositorio"
        return 0
    fi

    local count=$(jq length "$REPOS_FILE")
    print_info "Total de repositorios: $count"
    print_separator
    echo ""

    # Mostrar repositorios con formato mejorado
    local index=1
    jq -r '.[] | @base64' "$REPOS_FILE" | while read -r repo_data; do
        local repo_info=$(echo "$repo_data" | base64 -d)
        
        local name=$(echo "$repo_info" | jq -r '.name')
        local path=$(echo "$repo_info" | jq -r '.local_path')
        local url=$(echo "$repo_info" | jq -r '.url // "No configurada"')
        local private=$(echo "$repo_info" | jq -r '.private')
        local desc=$(echo "$repo_info" | jq -r '.description')
        local created=$(echo "$repo_info" | jq -r '.created_at')
        
        # Verificar si el directorio existe
        local status_icon="${GREEN}✓${NC}"
        local status_text="Disponible"
        
        if [ ! -d "$path" ]; then
            status_icon="${RED}✗${NC}"
            status_text="Directorio no encontrado"
        elif [ ! -d "$path/.git" ]; then
            status_icon="${YELLOW}⚠${NC}"
            status_text="No es repositorio Git"
        fi
        
        echo -e "${CYAN}${BOLD}[$index]${NC} ${WHITE}$name${NC} $status_icon"
        echo -e "    ${GRAY}Ruta:${NC} $path"
        echo -e "    ${GRAY}URL:${NC} $url"
        echo -e "    ${GRAY}Tipo:${NC} $([[ "$private" == "private" ]] && echo "${RED}Privado${NC}" || echo "${GREEN}Público${NC}")"
        echo -e "    ${GRAY}Estado:${NC} $status_text"
        echo -e "    ${GRAY}Descripción:${NC} $desc"
        echo -e "    ${GRAY}Creado:${NC} $(date -d "$created" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$created")"
        echo ""
        
        index=$((index + 1))
    done
}

# Función para inicializar repositorio mejorada
initialize_repository() {
    local repo_name="$1"
    local repo_path="$2"
    local description="$3"
    local is_private="$4"
    local template="$5"

    print_info "Inicializando repositorio: $repo_name"
    
    # Validar y crear ruta si no existe
    if [ ! -d "$repo_path" ]; then
        print_question "El directorio '$repo_path' no existe. ¿Deseas crearlo? (y/n)"
        read -r create_dir
        if [[ "$create_dir" =~ ^[yY]$ ]]; then
            mkdir -p "$repo_path"
            print_success "Directorio creado: $repo_path"
        else
            print_error "Operación cancelada"
            return 1
        fi
    fi

    cd "$repo_path" || return 1

    # Crear backup si ya existe contenido
    if [ "$(ls -A .)" ]; then
        create_backup "$repo_path"
    fi

    # Inicializar git si no existe
    if [ ! -d ".git" ]; then
        git init
        git config init.defaultBranch main
        print_success "Repositorio Git inicializado con rama 'main'"
    fi

    # Crear plantilla si se especificó
    if [ -n "$template" ] && [ "$template" != "basic" ]; then
        create_project_template "$template" "$repo_path" "$repo_name"
    fi

    # Crear .gitignore básico si no existe
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore << EOF
# Archivos del sistema
.DS_Store
Thumbs.db
*.log

# Archivos temporales
*.tmp
*.temp
*~

# Directorios de dependencias
node_modules/
venv/
__pycache__/

# Archivos de configuración local
.env
.env.local
config.local.*

# Archivos de IDE
.vscode/
.idea/
*.swp
*.swo
EOF
        print_success ".gitignore creado"
    fi

    # Crear README mejorado si no existe
    if [ ! -f "README.md" ]; then
        cat > README.md << EOF
# $repo_name

$description

## 📋 Descripción

[Describe aquí tu proyecto de manera detallada]

## 🚀 Instalación

\`\`\`bash
# Clonar el repositorio
git clone <url-del-repositorio>

# Entrar al directorio
cd $repo_name

# Instalar dependencias (si aplica)
# npm install  # Para Node.js
# pip install -r requirements.txt  # Para Python
\`\`\`

## 💻 Uso

\`\`\`bash
# Ejecutar la aplicación
[Comandos para ejecutar tu proyecto]
\`\`\`

## 🛠️ Tecnologías

- [Lista las tecnologías utilizadas]

## 📁 Estructura del Proyecto

\`\`\`
$repo_name/
├── README.md
├── .gitignore
└── [otros archivos]
\`\`\`

## 🤝 Contribuir

Las contribuciones son bienvenidas. Para contribuir:

1. Haz fork del proyecto
2. Crea una rama para tu feature (\`git checkout -b feature/AmazingFeature\`)
3. Commit tus cambios (\`git commit -m 'Add some AmazingFeature'\`)
4. Push a la rama (\`git push origin feature/AmazingFeature\`)
5. Abre un Pull Request

## 📝 Licencia

Este proyecto está bajo la Licencia [MIT/GPL/Apache] - ver el archivo [LICENSE](LICENSE) para más detalles.

## 👤 Autor

**$FULL_NAME**
- GitHub: [@$GITHUB_USER](https://github.com/$GITHUB_USER)
- Email: $GITHUB_EMAIL

---

⭐ ¡No olvides darle una estrella a este proyecto si te ha sido útil!

*Proyecto creado con [Git Automation Tool](https://github.com/tu-usuario/git-automation-tool) v$VERSION*
EOF
        print_success "README.md creado con plantilla profesional"
    fi

    # Crear repositorio en GitHub
    local privacy_flag="false"
    [[ "$is_private" == "true" ]] && privacy_flag="true"

    print_info "Creando repositorio en GitHub..."
    show_progress 3 "Configurando repositorio remoto"

    local response
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                    -H "Content-Type: application/json" \
                    -X POST \
                    -d "{\"name\":\"$repo_name\",\"description\":\"$description\",\"private\":$privacy_flag,\"auto_init\":false}" \
                    https://api.github.com/user/repos)

    if echo "$response" | jq -e '.clone_url' &> /dev/null; then
        local repo_url
        repo_url=$(echo "$response" | jq -r '.clone_url')
        print_success "Repositorio creado en GitHub: $repo_url"
        
        # Configurar remote origin
        if git remote get-url origin &> /dev/null; then
            git remote set-url origin "$repo_url"
        else
            git remote add origin "$repo_url"
        fi
        print_success "Remote origin configurado"
        
        # Hacer primer commit
        git add .
        git commit -m "🎉 Initial commit

- Proyecto inicializado con Git Automation Tool v$VERSION
- README.md creado con documentación básica
- .gitignore configurado
$([ -n "$template" ] && echo "- Plantilla '$template' aplicada")

Creado por: $FULL_NAME
Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
        
        # Push inicial
        show_progress 2 "Subiendo código inicial"
        if git push -u origin main; then
            print_success "Código subido exitosamente a GitHub"
        else
            print_warning "Error al subir código. Reintentando..."
            if git push -u origin master; then
                print_success "Código subido exitosamente a GitHub (rama master)"
            else
                print_error "Error al subir código a GitHub"
                return 1
            fi
        fi
        
        # Registrar repositorio automáticamente
        if [ -f "$REPOS_FILE" ]; then
            local temp_file=$(mktemp)
            jq --arg name "$repo_name" \
               --arg url "$repo_url" \
               --arg path "$repo_path" \
               --arg desc "$description" \
               --arg privacy "$([[ "$is_private" == "true" ]] && echo "private" || echo "public")" \
               --arg created "$(date -Iseconds)" \
               '. += [{
                   "name": $name,
                   "url": $url,
                   "local_path": $path,
                   "description": $desc,
                   "private": $privacy,
                   "created_at": $created,
                   "last_updated": $created,
                   "template": "'$template'"
               }]' "$REPOS_FILE" > "$temp_file"
            mv "$temp_file" "$REPOS_FILE"
            print_success "Repositorio registrado automáticamente"
        fi
        
        return 0
    else
        local error_message
        error_message=$(echo "$response" | jq -r '.message // "Error desconocido"')
        print_error "Error al crear repositorio en GitHub: $error_message"
        
        # Mostrar detalles del error si está disponible
        if echo "$response" | jq -e '.errors' &> /dev/null; then
            local errors
            errors=$(echo "$response" | jq -r '.errors[].message' 2>/dev/null)
            if [ -n "$errors" ]; then
                print_info "Detalles del error:"
                echo "$errors" | while read -r line; do
                    echo "  • $line"
                done
            fi
        fi
        
        return 1
    fi
}

# Función para subir cambios mejorada
upload_changes() {
    local target_path="$1"
    local commit_message="$2"
    local branch="$3"
    local force_push="$4"
    local auto_backup="$5"

    # Validar ruta
    if [ ! -e "$target_path" ]; then
        print_error "La ruta no existe: $target_path"
        return 1
    fi

    # Determinar directorio de trabajo
    local work_dir
    if [ -d "$target_path" ]; then
        work_dir="$target_path"
    else
        work_dir=$(dirname "$target_path")
    fi

    cd "$work_dir" || return 1

    # Verificar si es un repositorio Git
    if [ ! -d ".git" ]; then
        print_error "No es un repositorio Git: $work_dir"
        print_question "¿Deseas inicializarlo? (y/n)"
        read -r response
        if [[ "$response" =~ ^[yY]$ ]]; then
            git init
            git config init.defaultBranch main
            print_success "Repositorio Git inicializado"
        else
            return 1
        fi
    fi

    # Crear backup si está habilitado
    if [[ "$auto_backup" == "true" || "$AUTO_BACKUP" == "true" ]]; then
        create_backup "$work_dir"
    fi

    # Verificar estado del repositorio
    local git_status
    git_status=$(git status --porcelain 2>/dev/null)
    
    if [ -z "$git_status" ]; then
        print_warning "No hay cambios para subir"
        show_repo_stats "$work_dir"
        return 0
    fi

    # Mostrar estado actual con más detalle
    print_info "Analizando cambios en el repositorio..."
    echo ""
    echo -e "${BOLD}${WHITE}📊 RESUMEN DE CAMBIOS:${NC}"
    
    local new_files=$(echo "$git_status" | grep -c "^??" || echo "0")
    local modified_files=$(echo "$git_status" | grep -c "^ M" || echo "0")
    local deleted_files=$(echo "$git_status" | grep -c "^ D" || echo "0")
    local staged_files=$(echo "$git_status" | grep -c "^[MARC]" || echo "0")
    
    echo -e "${GREEN}  • Archivos nuevos: $new_files${NC}"
    echo -e "${YELLOW}  • Archivos modificados: $modified_files${NC}"
    echo -e "${RED}  • Archivos eliminados: $deleted_files${NC}"
    echo -e "${CYAN}  • Archivos en staging: $staged_files${NC}"
    
    echo ""
    print_info "Estado detallado:"
    git status --short | while read -r line; do
        local status="${line:0:2}"
        local file="${line:3}"
        
        case "$status" in
            "??") echo -e "${GREEN}  + $file${NC} (nuevo)" ;;
            " M") echo -e "${YELLOW}  ~ $file${NC} (modificado)" ;;
            " D") echo -e "${RED}  - $file${NC} (eliminado)" ;;
            "A ") echo -e "${CYAN}  ✓ $file${NC} (agregado)" ;;
            "M ") echo -e "${CYAN}  ✓ $file${NC} (modificado, en staging)" ;;
            *) echo -e "${GRAY}  $status $file${NC}" ;;
        esac
    done

    echo ""
    print_question "¿Deseas continuar con la subida? (y/n)"
    read -r confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        print_info "Operación cancelada"
        return 0
    fi

    # Agregar archivos
    show_progress 1 "Preparando archivos"
    
    if [ -f "$target_path" ]; then
        git add "$target_path"
        print_success "Archivo agregado: $target_path"
    else
        # Preguntar si agregar archivos nuevos
        if [ "$new_files" -gt 0 ]; then
            print_question "¿Agregar archivos nuevos? (y/n)"
            read -r add_new
            if [[ "$add_new" =~ ^[yY]$ ]]; then
                git add .
            else
                git add -u
            fi
        else
            git add .
        fi
        print_success "Cambios agregados al staging area"
    fi

    # Generar mensaje de commit inteligente
    local final_message
    if [ -n "$commit_message" ]; then
        final_message="$commit_message"
    else
        # Generar mensaje automático basado en cambios
        local auto_message="📝 Actualización automática"
        
        if [ "$new_files" -gt 0 ] && [ "$modified_files" -eq 0 ] && [ "$deleted_files" -eq 0 ]; then
            auto_message="✨ Agregar nuevos archivos ($new_files archivos)"
        elif [ "$new_files" -eq 0 ] && [ "$modified_files" -gt 0 ] && [ "$deleted_files" -eq 0 ]; then
            auto_message="🔧 Actualizar archivos existentes ($modified_files archivos)"
        elif [ "$deleted_files" -gt 0 ]; then
            auto_message="🗑️ Actualizar y limpiar archivos"
        elif [ "$new_files" -gt 0 ] && [ "$modified_files" -gt 0 ]; then
            auto_message="🚀 Actualización completa (nuevos: $new_files, modificados: $modified_files)"
        fi
        
        auto_message="$auto_message

Generado automáticamente el $(date '+%Y-%m-%d %H:%M:%S')
Por: $FULL_NAME"
        
        final_message="$auto_message"
    fi

    # Commit
    show_progress 1 "Creando commit"
    if git commit -m "$final_message"; then
        print_success "Commit realizado exitosamente"
        
        # Mostrar información del commit
        local commit_hash=$(git rev-parse --short HEAD)
        print_info "Hash del commit: $commit_hash"
    else
        print_error "Error al crear commit"
        return 1
    fi

    # Determinar rama
    local current_branch
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    local target_branch="${branch:-$current_branch}"

    # Verificar remote origin
    if ! git remote get-url origin &> /dev/null; then
        print_error "No se encontró remote origin configurado"
        print_question "¿Deseas configurar un repositorio remoto? (y/n)"
        read -r setup_remote
        if [[ "$setup_remote" =~ ^[yY]$ ]]; then
            print_question "Ingresa la URL del repositorio remoto:"
            read -r remote_url
            git remote add origin "$remote_url"
            print_success "Remote origin configurado"
        else
            print_info "Commit local realizado, pero no se subió a repositorio remoto"
            return 0
        fi
    fi

    # Verificar conectividad antes de push
    print_info "Verificando conectividad con el repositorio remoto..."
    if ! git ls-remote origin &> /dev/null; then
        print_error "No se puede conectar al repositorio remoto"
        print_info "Verifica tu conexión a internet y las credenciales"
        return 1
    fi

    # Push con progreso
    show_progress 3 "Subiendo cambios al repositorio remoto"
    
    local push_args=()
    if [ "$force_push" = "true" ]; then
        push_args+=("--force-with-lease")
        print_warning "Usando force push con protección (--force-with-lease)"
    fi

    # Intentar push
    if git push "${push_args[@]}" origin "$target_branch" 2>/dev/null; then
        print_success "✨ Cambios subidos exitosamente a la rama: $target_branch"
        
        # Mostrar información adicional
        local repo_url
        repo_url=$(git config --get remote.origin.url | sed 's/\.git$//')
        if [[ "$repo_url" == *"github.com"* ]]; then
            repo_url=$(echo "$repo_url" | sed 's/git@github.com:/https:\/\/github.com\//')
            print_info "🌐 Ver en GitHub: $repo_url"
        fi
        
        # Actualizar registro del repositorio
        update_repo_registry "$work_dir"
        
    else
        print_warning "Error en el push inicial, analizando problema..."
        
        # Intentar fetch para ver si hay conflictos
        git fetch origin "$target_branch" 2>/dev/null
        
        local behind_count
        behind_count=$(git rev-list --count HEAD..origin/"$target_branch" 2>/dev/null || echo "0")
        
        if [ "$behind_count" -gt 0 ]; then
            print_warning "El repositorio local está $behind_count commits atrás del remoto"
            print_question "¿Deseas hacer pull primero? (y/n)"
            read -r do_pull
            if [[ "$do_pull" =~ ^[yY]$ ]]; then
                if git pull origin "$target_branch"; then
                    print_success "Pull realizado exitosamente"
                    if git push origin "$target_branch"; then
                        print_success "✨ Cambios subidos exitosamente después del pull"
                        update_repo_registry "$work_dir"
                    else
                        print_error "Error al subir cambios después del pull"
                        return 1
                    fi
                else
                    print_error "Error durante el pull. Posibles conflictos"
                    print_info "Resuelve los conflictos manualmente y ejecuta el script nuevamente"
                    return 1
                fi
            else
                print_error "Push cancelado debido a divergencia con el remoto"
                return 1
            fi
        else
            print_error "Error desconocido al subir cambios"
            print_info "Ejecuta 'git push origin $target_branch' manualmente para más detalles"
            return 1
        fi
    fi
}

# Función para actualizar registro de repositorio
update_repo_registry() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    if [ -f "$REPOS_FILE" ]; then
        local temp_file=$(mktemp)
        jq --arg path "$repo_path" \
           --arg updated "$(date -Iseconds)" \
           'map(if .local_path == $path then . + {"last_updated": $updated} else . end)' \
           "$REPOS_FILE" > "$temp_file"
        mv "$temp_file" "$REPOS_FILE"
    fi
}

# Función para actualizar repositorio existente mejorada
update_repository() {
    local repo_path="$1"

    cd "$repo_path" || return 1

    # Verificar si es un repositorio Git
    if [ ! -d ".git" ]; then
        print_error "No es un repositorio Git: $repo_path"
        return 1
    fi

    print_info "Actualizando repositorio: $(basename "$repo_path")"
    show_repo_stats "$repo_path"

    # Crear backup antes de actualizar
    create_backup "$repo_path"

    # Verificar conectividad
    print_info "Verificando conexión con el repositorio remoto..."
    if ! git ls-remote origin &> /dev/null; then
        print_error "No se puede conectar al repositorio remoto"
        return 1
    fi

    # Fetch cambios remotos con progreso
    show_progress 2 "Obteniendo cambios remotos"
    if git fetch --all --prune; then
        print_success "Cambios remotos obtenidos"
    else
        print_warning "Error al obtener cambios remotos"
    fi

    # Analizar estado del repositorio
    local current_branch
    current_branch=$(git symbolic-ref --short HEAD)
    
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse origin/"$current_branch" 2>/dev/null || echo "")
    
    local ahead_count=0
    local behind_count=0
    
    if [ -n "$remote_commit" ]; then
        ahead_count=$(git rev-list --count origin/"$current_branch"..HEAD 2>/dev/null || echo "0")
        behind_count=$(git rev-list --count HEAD..origin/"$current_branch" 2>/dev/null || echo "0")
    fi

    echo ""
    print_info "Estado de sincronización:"
    echo -e "${WHITE}  • Rama actual: $current_branch${NC}"
    echo -e "${WHITE}  • Commits adelante: ${GREEN}$ahead_count${NC}"
    echo -e "${WHITE}  • Commits atrás: ${YELLOW}$behind_count${NC}"

    # Verificar si hay cambios locales sin confirmar
    local uncommitted_changes
    uncommitted_changes=$(git status --porcelain)
    
    if [ -n "$uncommitted_changes" ]; then
        echo ""
        print_warning "Hay cambios locales sin confirmar:"
        git status --short
        echo ""
        print_question "¿Qué deseas hacer?"
        echo "1. Hacer commit de los cambios locales"
        echo "2. Descartar los cambios locales (PELIGROSO)"
        echo "3. Hacer stash de los cambios (guardar temporalmente)"
        echo "4. Cancelar operación"
        
        read -r choice
        case "$choice" in
            1)
                print_question "Ingresa el mensaje de commit:"
                read -r commit_msg
                git add .
                if git commit -m "${commit_msg:-"Cambios locales - $(date +"%Y-%m-%d %H:%M:%S")"}"; then
                    print_success "Commit local realizado"
                    ahead_count=$((ahead_count + 1))
                else
                    print_error "Error al hacer commit"
                    return 1
                fi
                ;;
            2)
                print_warning "⚠️  ADVERTENCIA: Esta acción eliminará todos los cambios locales"
                print_question "¿Estás completamente seguro? Escribe 'SI' para confirmar:"
                read -r confirm
                if [ "$confirm" = "SI" ]; then
                    git reset --hard HEAD
                    git clean -fd
                    print_warning "Cambios locales descartados"
                else
                    print_info "Operación cancelada"
                    return 0
                fi
                ;;
            3)
                if git stash push -m "Auto stash - $(date +"%Y-%m-%d %H:%M:%S")"; then
                    print_success "Cambios guardados en stash"
                    print_info "Usa 'git stash pop' para recuperar los cambios después"
                else
                    print_error "Error al hacer stash"
                    return 1
                fi
                ;;
            *)
                print_info "Operación cancelada"
                return 0
                ;;
        esac
    fi

    # Actualizar repositorio según el estado
    if [ "$behind_count" -gt 0 ]; then
        show_progress 3 "Actualizando desde repositorio remoto"
        
        if [ "$ahead_count" -gt 0 ]; then
            print_info "Sincronizando cambios locales y remotos..."
            if git pull --rebase origin "$current_branch"; then
                print_success "Repositorio sincronizado con rebase"
            else
                print_error "Conflicto durante rebase. Resuelve manualmente los conflictos"
                print_info "Comandos útiles:"
                echo "  git status          # Ver archivos en conflicto"
                echo "  git add <archivo>   # Marcar conflicto como resuelto"
                echo "  git rebase --continue  # Continuar rebase"
                echo "  git rebase --abort     # Cancelar rebase"
                return 1
            fi
        else
            if git pull origin "$current_branch"; then
                print_success "Repositorio actualizado desde remoto"
            else
                print_error "Error al actualizar repositorio"
                return 1
            fi
        fi
    elif [ "$ahead_count" -gt 0 ]; then
        print_info "El repositorio local está adelante del remoto"
        print_question "¿Deseas subir los cambios locales? (y/n)"
        read -r push_changes
        if [[ "$push_changes" =~ ^[yY]$ ]]; then
            show_progress 2 "Subiendo cambios locales"
            if git push origin "$current_branch"; then
                print_success "Cambios locales subidos exitosamente"
            else
                print_error "Error al subir cambios"
                return 1
            fi
        fi
    else
        print_success "El repositorio ya está actualizado"
    fi

    # Mostrar estadísticas finales
    echo ""
    show_repo_stats "$repo_path"
    
    # Actualizar registro
    update_repo_registry "$repo_path"
}

# Función para clonar repositorio mejorada
clone_repository() {
    print_banner
    echo -e "${WHITE}${BOLD}=== CLONAR REPOSITORIO ===${NC}"
    echo ""
    
    print_question "Ingresa la URL del repositorio a clonar:"
    read -r repo_url
    
    # Validar URL
    if [[ ! "$repo_url" =~ ^https?://|^git@ ]]; then
        print_error "URL inválida. Debe comenzar con https:// o git@"
        return 1
    fi
    
    print_question "Ingresa el directorio destino (Enter para usar nombre del repo):"
    read -r dest_dir

    # Obtener nombre del repositorio si no se especifica directorio
    if [ -z "$dest_dir" ]; then
        dest_dir=$(basename "$repo_url" .git)
        print_info "Usando directorio: $dest_dir"
    fi

    # Verificar si el directorio ya existe
    i    # Verificar si el directorio ya existe
    if [ -d "$dest_dir" ]; then
        print_warning "El directorio '$dest_dir' ya existe"
        print_question "¿Deseas continuar y sobrescribir? (y/n)"
        read -r overwrite
        if [[ ! "$overwrite" =~ ^[yY]$ ]]; then
            print_info "Operación cancelada"
            return 0
        fi
        # Crear backup del directorio existente
        create_backup "$(pwd)/$dest_dir"
        rm -rf "$dest_dir"
    fi

    # Clonar repositorio con progreso
    print_info "Clonando repositorio..."
    show_progress 5 "Descargando código fuente"
    
    if git clone "$repo_url" "$dest_dir" 2>/dev/null; then
        print_success "Repositorio clonado exitosamente en: $dest_dir"
        
        # Configurar información del usuario si es necesario
        cd "$dest_dir" || return 1
        git config user.name "$FULL_NAME"
        git config user.email "$GITHUB_EMAIL"
        
        # Registrar repositorio automáticamente
        local repo_name=$(basename "$dest_dir")
        local remote_url=$(git config --get remote.origin.url)
        
        if [ -f "$REPOS_FILE" ]; then
            local temp_file=$(mktemp)
            jq --arg name "$repo_name" \
               --arg url "$remote_url" \
               --arg path "$(pwd)/$dest_dir" \
               --arg desc "Repositorio clonado de $remote_url" \
               --arg created "$(date -Iseconds)" \
               '. += [{
                   "name": $name,
                   "url": $url,
                   "local_path": $path,
                   "description": $desc,
                   "private": "unknown",
                   "created_at": $created,
                   "last_updated": $created,
                   "source": "cloned"
               }]' "$REPOS_FILE" > "$temp_file"
            mv "$temp_file" "$REPOS_FILE"
            print_success "Repositorio registrado automáticamente"
        fi
        
        # Mostrar información del repositorio clonado
        echo ""
        show_repo_stats "$dest_dir"
        
        return 0
    else
        print_error "Error al clonar el repositorio"
        print_info "Verifica:"
        echo "  • La URL del repositorio"
        echo "  • Tus permisos de acceso"
        echo "  • Tu conexión a internet"
        return 1
    fi
}

# Función principal mejorada
main() {
    # Verificar dependencias
    check_dependencies
    
    # Configurar directorios
    setup_config_dir
    
    # Manejar opciones
    local action=""
    local target_path=""
    local commit_message=""
    local branch=""
    local force_push="false"
    local auto_backup="$AUTO_BACKUP"
    local repo_name=""
    local description=""
    local is_private="false"
    local template=""
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo -e "${CYAN}${BOLD}$SCRIPT_NAME v$VERSION${NC}"
                echo "Herramienta profesional de automatización Git/GitHub"
                exit 0
                ;;
            -S|--subir)
                action="upload"
                shift
                ;;
            -C|--clonar)
                action="clone"
                shift
                ;;
            -I|--init)
                action="init"
                shift
                ;;
            -U|--update)
                action="update"
                shift
                ;;
            -R|--registrar)
                action="register"
                shift
                ;;
            -L|--listar)
                action="list"
                shift
                ;;
            --config)
                configure_credentials
                exit 0
                ;;
            --stats)
                action="stats"
                shift
                ;;
            --backup)
                action="backup"
                shift
                ;;
            --interactive)
                interactive_mode
                exit 0
                ;;
            --log)
                show_logs
                exit 0
                ;;
            --cleanup)
                cleanup_old_backups
                print_success "Limpieza completada"
                exit 0
                ;;
            --export-config)
                print_info "Exportando configuración..."
                if [ -f "$CONFIG_FILE" ]; then
                    cat "$CONFIG_FILE"
                else
                    print_error "No hay configuración para exportar"
                fi
                exit 0
                ;;
            --import-config)
                print_info "Importando configuración..."
                cat > "$CONFIG_FILE"
                print_success "Configuración importada"
                exit 0
                ;;
            --path)
                target_path="$2"
                shift 2
                ;;
            --message)
                commit_message="$2"
                shift 2
                ;;
            --branch)
                branch="$2"
                shift 2
                ;;
            --force)
                force_push="true"
                shift
                ;;
            --auto-backup)
                auto_backup="true"
                shift
                ;;
            --name)
                repo_name="$2"
                shift 2
                ;;
            --description)
                description="$2"
                shift 2
                ;;
            --private)
                is_private="true"
                shift
                ;;
            --public)
                is_private="false"
                shift
                ;;
            --template)
                template="$2"
                shift 2
                ;;
            *)
                print_error "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Mostrar banner
    print_banner
    
    # Ejecutar acción según parámetros
    case $action in
        "upload")
            load_config
            if [ -z "$target_path" ]; then
                target_path="."
            fi
            upload_changes "$target_path" "$commit_message" "$branch" "$force_push" "$auto_backup"
            ;;
        "clone")
            load_config
            clone_repository
            ;;
        "init")
            load_config
            if [ -z "$repo_name" ]; then
                print_error "Se requiere --name para inicializar repositorio"
                exit 1
            fi
            if [ -z "$target_path" ]; then
                target_path="./$repo_name"
            fi
            initialize_repository "$repo_name" "$target_path" "$description" "$is_private" "$template"
            ;;
        "update")
            load_config
            if [ -z "$target_path" ]; then
                target_path="."
            fi
            update_repository "$target_path"
            ;;
        "register")
            load_config
            register_repository
            ;;
        "list")
            list_repositories
            ;;
        "stats")
            if [ -z "$target_path" ]; then
                target_path="."
            fi
            show_repo_stats "$target_path"
            ;;
        "backup")
            if [ -z "$target_path" ]; then
                target_path="."
            fi
            create_backup "$target_path"
            ;;
        "")
            print_warning "No se especificó ninguna acción"
            echo ""
            print_info "Usa --help para ver las opciones disponibles"
            print_info "O usa --interactive para el modo interactivo"
            ;;
        *)
            print_error "Acción desconocida: $action"
            exit 1
            ;;
    esac
}

# Manejo de señales para limpieza
cleanup() {
    print_info "Limpiando recursos..."
    # Aquí puedes agregar código de limpieza si es necesario
    exit 0
}

# Configurar manejo de señales
trap cleanup EXIT INT TERM

# Punto de entrada principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
