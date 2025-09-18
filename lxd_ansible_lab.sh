#!/bin/bash
# Script avanzado de configuración LXD para laboratorio Ansible
# Autor: Sistema completo de laboratorio para práctica de Ansible
# Versión: 3.0 - Laboratorio Completo

# ========== 1. CONFIGURACIÓN INICIAL ==========
# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Variables globales de configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/lxd_ansible_lab_$(date +%Y%m%d_%H%M%S).log"
ANSIBLE_DIR="$HOME/ansible-lab"
INVENTORY_FILE="$ANSIBLE_DIR/inventory"
PLAYBOOK_DIR="$ANSIBLE_DIR/playbooks"
SSH_KEY_PATH="$HOME/.ssh/ansible-lab"

# Requisitos mínimos
MIN_RAM_GB=8
MIN_DISK_GB=30
MIN_CPU_CORES=4

# Configuración del laboratorio
LAB_NETWORK="ansible-lab"
LAB_SUBNET="10.200.1.0/24"
LAB_BRIDGE="lxdbr-ansible"
ANSIBLE_USER="ansible"
ANSIBLE_PASSWORD="ansible123"

# Configuración de máquinas del laboratorio
declare -A LAB_MACHINES
LAB_MACHINES=(
    ["control"]="ubuntu/20.04:10.200.1.10:Control Node (Ansible Master)"
    ["web1"]="ubuntu/22.04:10.200.1.11:Web Server 1 (Apache/Nginx)"
    ["web2"]="centos/8:10.200.1.12:Web Server 2 (CentOS)"
    ["db1"]="debian/11:10.200.1.13:Database Server 1 (MySQL/PostgreSQL)"
    ["db2"]="fedora/37:10.200.1.14:Database Server 2 (Fedora)"
    ["monitoring"]="alpine/3.17:10.200.1.15:Monitoring Server (Prometheus/Grafana)"
)

# Arrays para tracking
CONTAINERS=()
FAILED_CONTAINERS=()
CLEANUP_ON_EXIT=false

# ========== 2. FUNCIONES DE UTILIDAD ==========
# Función de logging mejorada
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Función para mostrar header mejorado
show_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}${BOLD}              LABORATORIO LXD PARA ANSIBLE - v3.0                    ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}║${WHITE}         Sistema Completo de Práctica con 6 Máquinas Virtuales        ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}🚀 Configurando un laboratorio completo para práctica de Ansible${NC}"
    echo -e "${CYAN}📦 6 contenedores con diferentes distribuciones Linux${NC}"
    echo -e "${CYAN}🌐 Red privada configurada automáticamente${NC}"
    echo -e "${CYAN}🔧 Ansible instalado y configurado${NC}"
    echo ""
}

# ========== 3. FUNCIONES DE DETECCIÓN Y VERIFICACIÓN ==========
# Función para detectar el sistema operativo (mejorada)
detect_os() {
    log "INFO" "Detectando sistema operativo..."
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_ID="$ID"
        OS_CODENAME="${VERSION_CODENAME:-}"
    elif [[ -f /etc/redhat-release ]]; then
        OS_NAME=$(cat /etc/redhat-release)
        OS_ID="rhel"
    elif [[ -f /etc/debian_version ]]; then
        OS_NAME="Debian"
        OS_ID="debian"
    elif command -v uname >/dev/null 2>&1; then
        case "$(uname -s)" in
            SunOS)
                OS_NAME="Solaris"
                OS_ID="solaris"
                ;;
            AIX)
                OS_NAME="AIX"
                OS_ID="aix"
                ;;
            Darwin)
                OS_NAME="macOS"
                OS_ID="macos"
                ;;
            *)
                OS_NAME="Unknown Unix"
                OS_ID="unknown"
                ;;
        esac
    else
        OS_NAME="Unknown"
        OS_ID="unknown"
    fi
    echo -e "${CYAN}Sistema Host:${NC} $OS_NAME ($OS_ID) ${OS_VERSION:-}"
    log "INFO" "Sistema detectado: $OS_NAME ($OS_ID) ${OS_VERSION:-}"
}

# Función para verificar compatibilidad mejorada
check_lxd_compatibility() {
    log "INFO" "Verificando compatibilidad con LXD..."
    echo -e "
${BLUE}═══ ANÁLISIS DE COMPATIBILIDAD ═══${NC}"
    case "$OS_ID" in
        ubuntu|debian|pop|linuxmint|elementary)
            echo -e "${GREEN}✅ Totalmente compatible:${NC} LXD tiene soporte nativo óptimo"
            COMPATIBILITY_LEVEL="excellent"
            return 0
            ;;
        fedora|centos|rhel|rocky|alma|oracle)
            echo -e "${YELLOW}⚠️  Compatible:${NC} Requiere snap, funciona perfectamente"
            COMPATIBILITY_LEVEL="good"
            return 0
            ;;
        arch|manjaro|endeavour)
            echo -e "${YELLOW}⚠️  Compatible:${NC} Disponible via AUR, excelente rendimiento"
            COMPATIBILITY_LEVEL="good"
            return 0
            ;;
        opensuse*|sles|tumbleweed)
            echo -e "${YELLOW}⚠️  Limitado:${NC} Soporte experimental, puede funcionar"
            COMPATIBILITY_LEVEL="limited"
            return 0
            ;;
        solaris|aix|unknown)
            echo -e "${RED}❌ Incompatible:${NC} $OS_NAME no puede ejecutar contenedores LXD"
            echo -e "${RED}   Motivo técnico:${NC} LXD requiere kernel Linux >= 3.13 con:"
            echo -e "${RED}   • Namespaces (PID, NET, MNT, UTS, IPC)${NC}"
            echo -e "${RED}   • Control Groups (cgroups v1/v2)${NC}"
            echo -e "${RED}   • User Namespaces${NC}"
            echo -e "${RED}   • Bridge networking${NC}"
            COMPATIBILITY_LEVEL="incompatible"
            return 1
            ;;
        *)
            echo -e "${YELLOW}⚠️  Desconocido:${NC} Compatibilidad incierta, procediendo con precaución"
            COMPATIBILITY_LEVEL="unknown"
            return 2
            ;;
    esac
}

# Función para verificar recursos del sistema (mejorada para laboratorio)
check_system_resources() {
    log "INFO" "Verificando recursos del sistema para laboratorio Ansible..."
    echo -e "
${BLUE}═══ ANÁLISIS DE RECURSOS PARA LABORATORIO ═══${NC}"
    echo -e "${CYAN}Requisitos para laboratorio Ansible (6 contenedores):${NC}"
    echo -e "${CYAN}  • CPU: ${MIN_CPU_CORES}+ cores (recomendado para múltiples VMs)${NC}"
    echo -e "${CYAN}  • RAM: ${MIN_RAM_GB}+ GB (1-2GB por contenedor + overhead)${NC}"
    echo -e "${CYAN}  • Disco: ${MIN_DISK_GB}+ GB (sistema + contenedores + logs)${NC}"
    echo ""

    # Verificar CPU
    if command -v nproc >/dev/null 2>&1; then
        CPU_CORES=$(nproc)
    elif [[ -f /proc/cpuinfo ]]; then
        CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
    elif command -v sysctl >/dev/null 2>&1; then
        CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo "1")
    else
        CPU_CORES="1"
    fi

    # Obtener información detallada de CPU
    if [[ -f /proc/cpuinfo ]]; then
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        CPU_FREQ=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    fi

    echo -e "${CYAN}CPU:${NC} $CPU_CORES cores"
    [[ -n "$CPU_MODEL" ]] && echo -e "${CYAN}Modelo:${NC} $CPU_MODEL"
    [[ -n "$CPU_FREQ" ]] && echo -e "${CYAN}Frecuencia:${NC} ${CPU_FREQ} MHz"

    if [[ $CPU_CORES -ge $MIN_CPU_CORES ]]; then
        echo -e "${GREEN}✅ CPU:${NC} Óptimo para laboratorio ($CPU_CORES >= $MIN_CPU_CORES cores)"
        CPU_OK=true
    else
        echo -e "${YELLOW}⚠️  CPU:${NC} Limitado ($CPU_CORES < $MIN_CPU_CORES cores)"
        echo -e "${YELLOW}   El laboratorio funcionará pero puede ser lento${NC}"
        CPU_OK="limited"
    fi

    # Verificar RAM con información detallada
    if [[ -f /proc/meminfo ]]; then
        RAM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        RAM_AVAILABLE_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        RAM_TOTAL_GB=$((RAM_TOTAL_KB / 1024 / 1024))
        RAM_AVAILABLE_GB=$((RAM_AVAILABLE_KB / 1024 / 1024))
    elif command -v free >/dev/null 2>&1; then
        RAM_TOTAL_KB=$(free -k | grep ^Mem | awk '{print $2}')
        RAM_AVAILABLE_KB=$(free -k | grep ^Mem | awk '{print $7}')
        RAM_TOTAL_GB=$((RAM_TOTAL_KB / 1024 / 1024))
        RAM_AVAILABLE_GB=$((RAM_AVAILABLE_KB / 1024 / 1024))
    else
        RAM_TOTAL_GB=0
        RAM_AVAILABLE_GB=0
    fi

    echo -e "${CYAN}RAM Total:${NC} ${RAM_TOTAL_GB}GB"
    echo -e "${CYAN}RAM Disponible:${NC} ${RAM_AVAILABLE_GB}GB"

    if [[ $RAM_TOTAL_GB -ge $MIN_RAM_GB ]]; then
        echo -e "${GREEN}✅ RAM:${NC} Óptimo para laboratorio (${RAM_TOTAL_GB}GB >= ${MIN_RAM_GB}GB)"
        RAM_OK=true
    elif [[ $RAM_TOTAL_GB -ge 4 ]]; then
        echo -e "${YELLOW}⚠️  RAM:${NC} Limitado (${RAM_TOTAL_GB}GB < ${MIN_RAM_GB}GB)"
        echo -e "${YELLOW}   Se reducirá a 4 contenedores para optimizar memoria${NC}"
        RAM_OK="limited"
    else
        echo -e "${RED}❌ RAM:${NC} Insuficiente (${RAM_TOTAL_GB}GB < 4GB mínimo)"
        RAM_OK=false
    fi

    # Verificar swap
    if [[ -f /proc/meminfo ]]; then
        SWAP_TOTAL_KB=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
        SWAP_TOTAL_GB=$((SWAP_TOTAL_KB / 1024 / 1024))
        echo -e "${CYAN}Swap:${NC} ${SWAP_TOTAL_GB}GB"
    fi

    # Verificar espacio en disco detallado
    check_disk_space_detailed
}

# Función mejorada para verificar espacio en disco
check_disk_space_detailed() {
    echo -e "
${BLUE}═══ ANÁLISIS DETALLADO DE ALMACENAMIENTO ═══${NC}"
    local best_path="/"
    local best_space=0
    local paths_to_check=("/" "/var" "/home" "/opt" "/usr/local" "/tmp")

    echo -e "${CYAN}Analizando sistemas de archivos para laboratorio...${NC}"
    printf "%-15s %-15s %-10s %-10s %-15s\n" "MOUNT POINT" "FILESYSTEM" "TOTAL" "USADO" "DISPONIBLE"
    echo "────────────────────────────────────────────────────────────────────"

    for path in "${paths_to_check[@]}"; do
        if [[ -d "$path" ]]; then
            if command -v df >/dev/null 2>&1; then
                space_info=$(df -BG "$path" 2>/dev/null | tail -1)
                if [[ -n "$space_info" ]]; then
                    filesystem=$(echo "$space_info" | awk '{print $1}')
                    total_space=$(echo "$space_info" | awk '{print $2}' | sed 's/G//')
                    used_space=$(echo "$space_info" | awk '{print $3}' | sed 's/G//')
                    available_space=$(echo "$space_info" | awk '{print $4}' | sed 's/G//')
                    printf "%-15s %-15s %-10s %-10s %-15s\n" "$path" "$(basename $filesystem)" "${total_space}GB" "${used_space}GB" "${available_space}GB"
                    if [[ $available_space -gt $best_space ]]; then
                        best_space=$available_space
                        best_path=$path
                    fi
                fi
            fi
        fi
    done

    echo ""
    echo -e "${GREEN}📁 Mejor ubicación para laboratorio:${NC} $best_path (${best_space}GB disponible)"

    # Verificar tipo de sistema de archivos
    if command -v stat >/dev/null 2>&1; then
        FS_TYPE=$(stat -f -c %T "$best_path" 2>/dev/null || echo "unknown")
        echo -e "${CYAN}Tipo de filesystem:${NC} $FS_TYPE"
    fi

    if [[ $best_space -ge $MIN_DISK_GB ]]; then
        echo -e "${GREEN}✅ Almacenamiento:${NC} Óptimo (${best_space}GB >= ${MIN_DISK_GB}GB)"
        DISK_OK=true
        BEST_STORAGE_PATH="$best_path"
    elif [[ $best_space -ge 15 ]]; then
        echo -e "${YELLOW}⚠️  Almacenamiento:${NC} Limitado (${best_space}GB, mínimo ${MIN_DISK_GB}GB)"
        echo -e "${YELLOW}   Se usarán contenedores más pequeños${NC}"
        DISK_OK="limited"
        BEST_STORAGE_PATH="$best_path"
    else
        echo -e "${RED}❌ Almacenamiento:${NC} Insuficiente (${best_space}GB < 15GB mínimo)"
        DISK_OK=false
    fi
}

# Función para verificar kernel y características avanzadas
check_kernel_features() {
    log "INFO" "Verificando características avanzadas del kernel..."
    echo -e "
${BLUE}═══ ANÁLISIS AVANZADO DEL KERNEL ═══${NC}"
    if [[ -f /proc/version ]]; then
        kernel_version=$(uname -r)
        kernel_arch=$(uname -m)
        echo -e "${CYAN}Kernel:${NC} $kernel_version ($kernel_arch)"

        # Verificar versión del kernel
        kernel_major=$(echo "$kernel_version" | cut -d. -f1)
        kernel_minor=$(echo "$kernel_version" | cut -d. -f2)
        if [[ $kernel_major -gt 4 ]] || [[ $kernel_major -eq 4 && $kernel_minor -ge 4 ]]; then
            echo -e "${GREEN}✅ Versión del kernel:${NC} Óptima para contenedores"
        elif [[ $kernel_major -ge 3 && $kernel_minor -ge 13 ]]; then
            echo -e "${YELLOW}⚠️  Versión del kernel:${NC} Básica, funcional"
        else
            echo -e "${RED}❌ Versión del kernel:${NC} Muy antigua para LXD"
        fi

        # Verificar características necesarias para LXD
        echo -e "
${CYAN}Verificando características del kernel:${NC}"
        local features_ok=true

        # Namespaces
        local namespaces=("pid" "net" "mnt" "uts" "ipc" "user")
        for ns in "${namespaces[@]}"; do
            if [[ -f "/proc/self/ns/$ns" ]]; then
                echo -e "${GREEN}✅${NC} ${ns} namespace: Disponible"
            else
                echo -e "${RED}❌${NC} ${ns} namespace: No disponible"
                features_ok=false
            fi
        done

        # Control Groups
        if [[ -d /sys/fs/cgroup ]]; then
            if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
                echo -e "${GREEN}✅${NC} cgroups v2: Disponible (óptimo)"
            elif [[ -d /sys/fs/cgroup/cpu ]]; then
                echo -e "${YELLOW}⚠️${NC} cgroups v1: Disponible (funcional)"
            fi
        else
            echo -e "${RED}❌${NC} cgroups: No disponible"
            features_ok=false
        fi

        # User namespaces
        if [[ -f /proc/sys/kernel/unprivileged_userns_clone ]]; then
            userns_enabled=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo "0")
            if [[ "$userns_enabled" == "1" ]]; then
                echo -e "${GREEN}✅${NC} User namespaces: Habilitados"
            else
                echo -e "${YELLOW}⚠️${NC} User namespaces: Deshabilitados (se puede habilitar)"
            fi
        fi

        # Bridge networking
        if [[ -d /proc/sys/net/bridge ]] || lsmod | grep -q bridge; then
            echo -e "${GREEN}✅${NC} Bridge networking: Disponible"
        else
            echo -e "${YELLOW}⚠️${NC} Bridge networking: No cargado (se cargará automáticamente)"
        fi

        # Verificar módulos necesarios
        echo -e "
${CYAN}Verificando módulos del kernel:${NC}"
        local modules=("bridge" "veth" "xtables" "netfilter")
        for module in "${modules[@]}"; do
            if lsmod | grep -q "^${module}"; then
                echo -e "${GREEN}✅${NC} $module: Cargado"
            elif modinfo "$module" >/dev/null 2>&1; then
                echo -e "${YELLOW}⚠️${NC} $module: Disponible (se cargará)"
            else
                echo -e "${RED}❌${NC} $module: No disponible"
            fi
        done

        KERNEL_OK=$features_ok
    else
        echo -e "${YELLOW}⚠️${NC} No se puede verificar el kernel (no es Linux)"
        KERNEL_OK=false
    fi
}

# Función para verificar dependencias del sistema
check_system_dependencies() {
    log "INFO" "Verificando dependencias del sistema..."
    echo -e "
${BLUE}═══ VERIFICACIÓN DE DEPENDENCIAS ═══${NC}"
    # Verificar herramientas básicas
    local tools=("curl" "wget" "ssh" "git" "python3" "pip3")
    local missing_tools=()
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo -e "${GREEN}✅${NC} $tool: Disponible"
        else
            echo -e "${RED}❌${NC} $tool: No encontrado"
            missing_tools+=("$tool")
        fi
    done

    # Verificar Python y pip específicamente
    if command -v python3 >/dev/null 2>&1; then
        python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        echo -e "${CYAN}   Python version:${NC} $python_version"
        if command -v pip3 >/dev/null 2>&1; then
            pip_version=$(pip3 --version | cut -d' ' -f2)
            echo -e "${CYAN}   Pip version:${NC} $pip_version"
        fi
    fi

    # Instalar dependencias faltantes
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "
${YELLOW}📦 Instalando dependencias faltantes...${NC}"
        install_missing_dependencies "${missing_tools[@]}"
    fi
}

# Función para instalar dependencias faltantes
install_missing_dependencies() {
    local tools=("$@")
    case "$OS_ID" in
        ubuntu|debian|pop|linuxmint)
            sudo apt update
            for tool in "${tools[@]}"; do
                case "$tool" in
                    "pip3") sudo apt install -y python3-pip ;;
                    *) sudo apt install -y "$tool" ;;
                esac
            done
            ;;
        fedora|centos|rhel|rocky|alma)
            for tool in "${tools[@]}"; do
                case "$tool" in
                    "pip3") 
                        if command -v dnf >/dev/null 2>&1; then
                            sudo dnf install -y python3-pip
                        else
                            sudo yum install -y python3-pip
                        fi
                        ;;
                    *) 
                        if command -v dnf >/dev/null 2>&1; then
                            sudo dnf install -y "$tool"
                        else
                            sudo yum install -y "$tool"
                        fi
                        ;;
                esac
            done
            ;;
        arch|manjaro)
            for tool in "${tools[@]}"; do
                case "$tool" in
                    "pip3") sudo pacman -S --noconfirm python-pip ;;
                    *) sudo pacman -S --noconfirm "$tool" ;;
                esac
            done
            ;;
    esac
}

# ========== 4. FUNCIONES DE INSTALACIÓN ==========
# Función mejorada para instalar LXD
install_lxd() {
    log "INFO" "Iniciando instalación de LXD..."
    echo -e "
${BLUE}═══ INSTALACIÓN DE LXD ═══${NC}"
    # Verificar si ya está instalado
    if command -v lxd >/dev/null 2>&1; then
        local lxd_version=$(lxd --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✅ LXD ya está instalado:${NC} versión $lxd_version"
        return 0
    fi

    echo -e "${CYAN}Installing LXD para $OS_ID...${NC}"
    case "$OS_ID" in
        ubuntu|debian|pop|linuxmint|elementary)
            echo -e "${CYAN}Método: apt + snap (recomendado)${NC}"
            sudo apt update
            sudo apt install -y snapd lxd-client
            sudo snap install lxd
            ;;
        fedora|centos|rhel|rocky|alma|oracle)
            echo -e "${CYAN}Método: EPEL + snap${NC}"
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y epel-release snapd
                sudo systemctl enable --now snapd.socket
                sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true
            else
                sudo yum install -y epel-release snapd
                sudo systemctl enable --now snapd.socket
                sudo ln -sf /var/lib/snapd/snap /snap 2>/dev/null || true
            fi
            sleep 5
            sudo snap install lxd
            ;;
        arch|manjaro|endeavour)
            echo -e "${CYAN}Método: AUR${NC}"
            if command -v yay >/dev/null 2>&1; then
                yay -S --noconfirm lxd
            elif command -v paru >/dev/null 2>&1; then
                paru -S --noconfirm lxd
            else
                echo -e "${YELLOW}⚠️  Instalando yay helper para AUR...${NC}"
                sudo pacman -S --noconfirm base-devel git
                cd /tmp
                git clone https://aur.archlinux.org/yay.git
                cd yay
                makepkg -si --noconfirm
                yay -S --noconfirm lxd
            fi
            sudo systemctl enable --now lxd
            ;;
        opensuse*|sles|tumbleweed)
            echo -e "${CYAN}Método: zypper + snap${NC}"
            sudo zypper install -y snapd
            sudo systemctl enable --now snapd
            sudo snap install lxd
            ;;
        *)
            echo -e "${RED}❌ Instalación automática no disponible para $OS_ID${NC}"
            echo -e "${YELLOW}Consulta: https://linuxcontainers.org/lxd/getting-started-cli/${NC}"
            return 1
            ;;
    esac

    # Configurar usuario en grupo lxd
    sudo usermod -a -G lxd "$USER" 2>/dev/null || true

    # Verificar instalación
    sleep 3
    if command -v lxd >/dev/null 2>&1; then
        local lxd_version=$(lxd --version 2>/dev/null || echo "installed")
        echo -e "${GREEN}✅ LXD instalado correctamente:${NC} versión $lxd_version"
        echo -e "${YELLOW}⚠️  Nota:${NC} Puede necesitar reiniciar la sesión para usar LXD sin sudo"
        return 0
    else
        echo -e "${RED}❌ Error en la instalación de LXD${NC}"
        return 1
    fi
}

# Función para instalar Ansible
install_ansible() {
    log "INFO" "Instalando Ansible..."
    echo -e "
${BLUE}═══ INSTALACIÓN DE ANSIBLE ═══${NC}"
    if command -v ansible >/dev/null 2>&1; then
        local ansible_version=$(ansible --version | head -1 | cut -d' ' -f2)
        echo -e "${GREEN}✅ Ansible ya está instalado:${NC} versión $ansible_version"
        return 0
    fi

    echo -e "${CYAN}Instalando Ansible...${NC}"
    # Instalar via pip (método universal)
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --user ansible ansible-core
        # Agregar al PATH si no está
        export PATH="$HOME/.local/bin:$PATH"
        # Instalar colecciones básicas
        ansible-galaxy collection install community.general
        ansible-galaxy collection install ansible.posix
    else
        # Fallback a package manager
        case "$OS_ID" in
            ubuntu|debian|pop|linuxmint)
                sudo apt update
                sudo apt install -y ansible
                ;;
            fedora|centos|rhel|rocky|alma)
                if command -v dnf >/dev/null 2>&1; then
                    sudo dnf install -y ansible
                else
                    sudo yum install -y epel-release
                    sudo yum install -y ansible
                fi
                ;;
            arch|manjaro)
                sudo pacman -S --noconfirm ansible
                ;;
            opensuse*)
                sudo zypper install -y ansible
                ;;
        esac
    fi

    # Verificar instalación
    if command -v ansible >/dev/null 2>&1; then
        local ansible_version=$(ansible --version | head -1 | cut -d' ' -f2)
        echo -e "${GREEN}✅ Ansible instalado correctamente:${NC} versión $ansible_version"
        return 0
    else
        echo -e "${RED}❌ Error instalando Ansible${NC}"
        return 1
    fi
}

# ========== 5. FUNCIONES DE CONFIGURACIÓN DE LXD ==========
# Función para configurar LXD avanzado
configure_lxd_advanced() {
    log "INFO" "Configurando LXD para laboratorio Ansible..."
    echo -e "
${BLUE}═══ CONFIGURACIÓN AVANZADA DE LXD ═══${NC}"
    # Verificar si LXD ya está inicializado
    if lxd waitready --timeout=10 2>/dev/null && lxc profile show default >/dev/null 2>&1; then
        echo -e "${GREEN}✅ LXD ya está configurado${NC}"
    else
        echo -e "${CYAN}Inicializando LXD...${NC}"
        # Configuración automática con parámetros específicos para laboratorio
        if [[ -n "$BEST_STORAGE_PATH" && "$BEST_STORAGE_PATH" != "/" ]]; then
            storage_path="$BEST_STORAGE_PATH/lxd-storage"
            mkdir -p "$storage_path" 2>/dev/null || true
            lxd init --auto \
                --storage-backend dir \
                --storage-create-device \
                --storage-pool default \
                --network-address 0.0.0.0 \
                --network-port 8443 \
                --trust-password changeme123 \
                --storage-create-loop 10
        else
            lxd init --auto \
                --storage-backend dir \
                --network-address 0.0.0.0 \
                --network-port 8443 \
                --trust-password changeme123
        fi
    fi

    # Esperar a que LXD esté listo
    lxd waitready --timeout=30

    # Crear red personalizada para el laboratorio
    create_lab_network

    # Configurar perfil personalizado para laboratorio
    configure_lab_profile

    echo -e "${GREEN}✅ LXD configurado para laboratorio Ansible${NC}"
}

# Función para crear red personalizada del laboratorio
create_lab_network() {
    log "INFO" "Configurando red del laboratorio..."
    echo -e "
${CYAN}🌐 Configurando red privada del laboratorio...${NC}"
    # Verificar si la red ya existe
    if lxc network show "$LAB_NETWORK" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Red del laboratorio ya existe:${NC} $LAB_NETWORK"
    else
        echo -e "${CYAN}Creando red: $LAB_NETWORK ($LAB_SUBNET)${NC}"
        lxc network create "$LAB_NETWORK" \
            ipv4.address="10.200.1.1/24" \
            ipv4.dhcp=true \
            ipv4.dhcp.ranges="10.200.1.10-10.200.1.100" \
            ipv4.nat=true \
            ipv6.address=none \
            dns.domain="ansible-lab.local"
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Red del laboratorio creada exitosamente${NC}"
        else
            echo -e "${RED}❌ Error creando la red del laboratorio${NC}"
            return 1
        fi
    fi

    # Verificar conectividad de la red
    echo -e "${CYAN}Verificando configuración de red...${NC}"
    lxc network show "$LAB_NETWORK"
}

# Función para configurar perfil del laboratorio
configure_lab_profile() {
    log "INFO" "Configurando perfil del laboratorio..."
    echo -e "
${CYAN}📝 Configurando perfil del laboratorio...${NC}"
    # Crear perfil específico para laboratorio
    if lxc profile show ansible-lab >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Perfil del laboratorio ya existe${NC}"
    else
        lxc profile copy default ansible-lab
        # Configurar el perfil con ajustes optimizados
        lxc profile set ansible-lab limits.cpu 2
        lxc profile set ansible-lab limits.memory 1GB
        lxc profile device set ansible-lab eth0 network "$LAB_NETWORK"
        # Agregar configuración para SSH
        lxc profile set ansible-lab user.user-data - << 'EOF'
#cloud-config
package_update: true
package_upgrade: true
packages:
  - openssh-server
  - python3
  - python3-pip
  - curl
  - wget
  - vim
  - htop
  - net-tools
users:
  - name: ansible
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
    lock_passwd: false
    passwd: '$6$rounds=4096$saltsalt$hKMLjjK4dBZMJ7kE8/zKAJ5VR7mlG4PkwCpzCcE7sTDLyL2OT/VYVCdWnuV8xTDWrjABpKb5uyIiBM3c2CZ.Y0'
ssh_authorized_keys: []
runcmd:
  - systemctl enable ssh
  - systemctl start ssh
  - echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
  - echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
  - systemctl restart ssh
EOF
        echo -e "${GREEN}✅ Perfil del laboratorio configurado${NC}"
    fi
}

# ========== 6. FUNCIONES DE CONFIGURACIÓN DE ANSIBLE Y SSH ==========
# Función para generar claves SSH
generate_ssh_keys() {
    log "INFO" "Generando claves SSH para el laboratorio..."
    echo -e "
${BLUE}═══ CONFIGURACIÓN DE CLAVES SSH ═══${NC}"
    if [[ -f "$SSH_KEY_PATH" ]]; then
        echo -e "${GREEN}✅ Claves SSH del laboratorio ya existen${NC}"
    else
        echo -e "${CYAN}Generando par de claves SSH para el laboratorio...${NC}"
        # Crear directorio si no existe
        mkdir -p "$(dirname "$SSH_KEY_PATH")"
        # Generar clave SSH sin passphrase
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "ansible-lab-$(date +%Y%m%d)"
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Claves SSH generadas:${NC}"
            echo -e "${CYAN}  Privada:${NC} $SSH_KEY_PATH"
            echo -e "${CYAN}  Pública:${NC} $SSH_KEY_PATH.pub"
            # Configurar permisos
            chmod 600 "$SSH_KEY_PATH"
            chmod 644 "$SSH_KEY_PATH.pub"
        else
            echo -e "${RED}❌ Error generando claves SSH${NC}"
            return 1
        fi
    fi
}

# Función para crear directorio del laboratorio
setup_lab_directory() {
    log "INFO" "Configurando directorio del laboratorio..."
    echo -e "
${BLUE}═══ CONFIGURACIÓN DEL DIRECTORIO DE LABORATORIO ═══${NC}"
    # Crear estructura de directorios
    mkdir -p "$ANSIBLE_DIR"/{playbooks,inventory,roles,group_vars,host_vars,files,templates,logs}
    echo -e "${CYAN}Estructura del laboratorio creada en:${NC} $ANSIBLE_DIR"
    tree "$ANSIBLE_DIR" 2>/dev/null || ls -la "$ANSIBLE_DIR"

    # Crear archivo de configuración de Ansible
    create_ansible_config

    # Crear inventario dinámico
    create_dynamic_inventory

    # Crear playbooks de ejemplo
    create_sample_playbooks

    echo -e "${GREEN}✅ Directorio del laboratorio configurado${NC}"
}

# Función para crear configuración de Ansible
create_ansible_config() {
    local config_file="$ANSIBLE_DIR/ansible.cfg"
    echo -e "${CYAN}Creando configuración de Ansible...${NC}"
    cat > "$config_file" << 'EOF'
[defaults]
inventory = inventory
remote_user = ansible
private_key_file = ~/.ssh/ansible-lab
host_key_checking = False
stdout_callback = yaml
callback_whitelist = timer, profile_tasks
gathering = smart
fact_caching = jsonfile
fact_caching_connection = ./logs/facts_cache
fact_caching_timeout = 86400
log_path = ./logs/ansible.log
retry_files_enabled = True
retry_files_save_path = ./logs/
[inventory]
enable_plugins = host_list, script, auto, yaml, ini, toml
[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
pipelining = True
control_path = ./logs/%%h-%%p-%%r
EOF
    echo -e "${GREEN}✅ Configuración de Ansible creada${NC}"
}

# Función para crear inventario dinámico
create_dynamic_inventory() {
    echo -e "${CYAN}Creando inventario del laboratorio...${NC}"
    # Crear inventario estático inicial
    cat > "$INVENTORY_FILE" << 'EOF'
[control]
control ansible_host=10.200.1.10 ansible_user=ansible
[webservers]
web1 ansible_host=10.200.1.11 ansible_user=ansible
web2 ansible_host=10.200.1.12 ansible_user=ansible
[databases]
db1 ansible_host=10.200.1.13 ansible_user=ansible
db2 ansible_host=10.200.1.14 ansible_user=ansible
[monitoring]
monitoring ansible_host=10.200.1.15 ansible_user=ansible
[lab:children]
webservers
databases
monitoring
[ubuntu]
control
web1
db1
[centos]
web2
[debian]
db1
[fedora]
db2
[alpine]
monitoring
[lab:vars]
ansible_ssh_private_key_file=~/.ssh/ansible-lab
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

    # Crear script de inventario dinámico
    create_dynamic_inventory_script

    echo -e "${GREEN}✅ Inventario del laboratorio creado${NC}"
}

# Función para crear script de inventario dinámico
create_dynamic_inventory_script() {
    local script_file="$ANSIBLE_DIR/dynamic_inventory.py"
    cat > "$script_file" << 'EOF'
#!/usr/bin/env python3
import json
import subprocess
import sys

def get_lxc_containers():
    """Get LXC containers information"""
    try:
        result = subprocess.run(['lxc', 'list', '--format', 'json'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            return json.loads(result.stdout)
        else:
            return []
    except Exception:
        return []

def generate_inventory():
    """Generate dynamic inventory from LXC containers"""
    inventory = {
        '_meta': {
            'hostvars': {}
        },
        'all': {
            'children': ['ungrouped']
        },
        'ungrouped': {
            'hosts': []
        }
    }

    containers = get_lxc_containers()

    # Group containers by name patterns
    groups = {
        'control': [],
        'webservers': [],
        'databases': [],
        'monitoring': [],
        'lab': []
    }

    for container in containers:
        if container['status'] == 'Running':
            name = container['name']
            # Get IP address
            ip = None
            if 'eth0' in container['state']['network']:
                addresses = container['state']['network']['eth0']['addresses']
                for addr in addresses:
                    if addr['family'] == 'inet' and addr['scope'] == 'global':
                        ip = addr['address']
                        break

            if ip:
                # Categorize containers
                if 'control' in name:
                    groups['control'].append(name)
                elif 'web' in name:
                    groups['webservers'].append(name)
                elif 'db' in name:
                    groups['databases'].append(name)
                elif 'monitoring' in name:
                    groups['monitoring'].append(name)
                groups['lab'].append(name)

                # Add host variables
                inventory['_meta']['hostvars'][name] = {
                    'ansible_host': ip,
                    'ansible_user': 'ansible',
                    'ansible_ssh_private_key_file': '~/.ssh/ansible-lab',
                    'ansible_ssh_common_args': '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
                }

    # Add groups to inventory
    for group_name, hosts in groups.items():
        if hosts:
            inventory[group_name] = {'hosts': hosts}

    return inventory

if __name__ == '__main__':
    if len(sys.argv) == 2 and sys.argv[1] == '--list':
        inventory = generate_inventory()
        print(json.dumps(inventory, indent=2))
    elif len(sys.argv) == 3 and sys.argv[1] == '--host':
        print(json.dumps({}))
    else:
        print("Usage: {} --list or {} --host <hostname>".format(sys.argv[0], sys.argv[0]))
        sys.exit(1)
EOF
    chmod +x "$script_file"
    echo -e "${GREEN}✅ Script de inventario dinámico creado${NC}"
}

# Función para crear playbooks de ejemplo
create_sample_playbooks() {
    echo -e "${CYAN}Creando playbooks de ejemplo...${NC}"

    # Playbook básico de conectividad
    cat > "$PLAYBOOK_DIR/ping.yml" << 'EOF'
---
- name: Test connectivity to all hosts
  hosts: all
  gather_facts: false
  tasks:
    - name: Ping all hosts
      ping:
    - name: Gather facts
      setup:
    - name: Display host information
      debug:
        msg: "{{ inventory_hostname }} - {{ ansible_distribution }} {{ ansible_distribution_version }}"
EOF

    # Playbook de configuración básica
    cat > "$PLAYBOOK_DIR/basic_setup.yml" << 'EOF'
---
- name: Basic system setup
  hosts: all
  become: yes
  tasks:
    - name: Update package cache
      package:
        update_cache: yes
      when: ansible_os_family in ['Debian', 'RedHat']
    - name: Install basic packages
      package:
        name:
          - htop
          - vim
          - curl
          - wget
          - net-tools
        state: present
    - name: Create lab user if not exists
      user:
        name: labuser
        groups: sudo
        shell: /bin/bash
        create_home: yes
    - name: Set timezone
      timezone:
        name: America/Bogota
EOF

    # Playbook de configuración de servidores web
    cat > "$PLAYBOOK_DIR/webservers.yml" << 'EOF'
---
- name: Configure web servers
  hosts: webservers
  become: yes
  tasks:
    - name: Install Apache on Ubuntu/Debian
      package:
        name: apache2
        state: present
      when: ansible_os_family == 'Debian'
    - name: Install Apache on RedHat/CentOS
      package:
        name: httpd
        state: present
      when: ansible_os_family == 'RedHat'
    - name: Start and enable web service (Debian)
      systemd:
        name: apache2
        state: started
        enabled: yes
      when: ansible_os_family == 'Debian'
    - name: Start and enable web service (RedHat)
      systemd:
        name: httpd
        state: started
        enabled: yes
      when: ansible_os_family == 'RedHat'
    - name: Create simple index page
      copy:
        content: |
          <html>
          <head><title>{{ inventory_hostname }}</title></head>
          <body>
          <h1>Hello from {{ inventory_hostname }}</h1>
          <p>Server: {{ ansible_distribution }} {{ ansible_distribution_version }}</p>
          <p>IP: {{ ansible_default_ipv4.address }}</p>
          </body>
          </html>
        dest: /var/www/html/index.html
      notify: restart_webserver
  handlers:
    - name: restart_webserver
      systemd:
        name: "{{ 'apache2' if ansible_os_family == 'Debian' else 'httpd' }}"
        state: restarted
EOF

    # Playbook de monitoreo
    cat > "$PLAYBOOK_DIR/monitoring.yml" << 'EOF'
---
- name: Install monitoring tools
  hosts: monitoring
  become: yes
  tasks:
    - name: Install monitoring packages
      package:
        name:
          - htop
          - iotop
          - nmon
          - sysstat
        state: present
    - name: Create monitoring script
      copy:
        content: |
          #!/bin/bash
          echo "=== System Monitoring Report ==="
          echo "Date: $(date)"
          echo "Uptime: $(uptime)"
          echo "Memory Usage:"
          free -h
          echo "Disk Usage:"
          df -h
          echo "Network Interfaces:"
          ip -4 addr show
        dest: /usr/local/bin/system-report.sh
        mode: '0755'
EOF

    # Playbook completo del laboratorio
    cat > "$PLAYBOOK_DIR/lab_setup.yml" << 'EOF'
---
- import_playbook: ping.yml
- import_playbook: basic_setup.yml
- import_playbook: webservers.yml
- import_playbook: monitoring.yml
- name: Final lab configuration
  hosts: all
  gather_facts: yes
  tasks:
    - name: Display final status
      debug:
        msg: |
          Host: {{ inventory_hostname }}
          OS: {{ ansible_distribution }} {{ ansible_distribution_version }}
          IP: {{ ansible_default_ipv4.address }}
          Memory: {{ ansible_memtotal_mb }}MB
          CPU: {{ ansible_processor_cores }} cores
EOF

    echo -e "${GREEN}✅ Playbooks de ejemplo creados${NC}"
}

# ========== 7. FUNCIONES DE CREACIÓN DE CONTENEDORES ==========
# Función mejorada para crear contenedores del laboratorio
create_lab_containers() {
    log "INFO" "Creando contenedores del laboratorio Ansible..."
    echo -e "
${BLUE}═══ CREACIÓN DEL LABORATORIO (6 CONTENEDORES) ═══${NC}"
    local containers_created=0
    local total_containers=${#LAB_MACHINES[@]}

    # Verificar si tenemos recursos limitados
    if [[ "$RAM_OK" == "limited" ]]; then
        echo -e "${YELLOW}⚠️  Recursos limitados detectados - Reduciendo a 4 contenedores${NC}"
        total_containers=4
    fi

    echo -e "${CYAN}Creando $total_containers contenedores para el laboratorio...${NC}"
    echo ""

    local count=0
    for machine_name in "${!LAB_MACHINES[@]}"; do
        if [[ $count -ge $total_containers ]]; then
            break
        fi

        IFS=':' read -r image ip description <<< "${LAB_MACHINES[$machine_name]}"

        echo -e "${CYAN}[$((count+1))/$total_containers] Creando: ${BOLD}$machine_name${NC}${CYAN} ($description)${NC}"
        echo -e "${CYAN}                    Imagen: $image${NC}"
        echo -e "${CYAN}                    IP: $ip${NC}"

        # Verificar si el contenedor ya existe
        if lxc info "$machine_name" >/dev/null 2>&1; then
            echo -e "${YELLOW}   ⚠️  Contenedor ya existe, eliminando...${NC}"
            lxc stop "$machine_name" 2>/dev/null || true
            lxc delete "$machine_name" 2>/dev/null || true
            sleep 2
        fi

        # Crear el contenedor
        if timeout 120 lxc launch "images:$image" "$machine_name" --profile ansible-lab; then
            echo -e "${GREEN}   ✅ Contenedor creado exitosamente${NC}"
            CONTAINERS+=("$machine_name")
            ((containers_created++))

            # Esperar a que el contenedor esté listo
            echo -e "${CYAN}   🔄 Esperando que el contenedor esté listo...${NC}"
            local ready_count=0
            while [[ $ready_count -lt 30 ]]; do
                if lxc exec "$machine_name" -- echo "ready" >/dev/null 2>&1; then
                    break
                fi
                sleep 2
                ((ready_count++))
                echo -n "."
            done
            echo ""

            if [[ $ready_count -lt 30 ]]; then
                echo -e "${GREEN}   ✅ Contenedor listo y operativo${NC}"
                # Configurar IP estática
                configure_static_ip "$machine_name" "$ip"
                # Configurar SSH
                setup_container_ssh "$machine_name"
            else
                echo -e "${RED}   ❌ Timeout esperando que el contenedor esté listo${NC}"
                FAILED_CONTAINERS+=("$machine_name")
            fi
        else
            echo -e "${RED}   ❌ Error creando el contenedor${NC}"
            FAILED_CONTAINERS+=("$machine_name")
        fi

        echo ""
        ((count++))
        sleep 1
    done

    echo -e "${BLUE}═══ RESUMEN DE CREACIÓN ═══${NC}"
    echo -e "${GREEN}✅ Contenedores exitosos: $containers_created/$total_containers${NC}"
    if [[ ${#FAILED_CONTAINERS[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Contenedores fallidos: ${FAILED_CONTAINERS[*]}${NC}"
    fi

    # Listar contenedores creados
    if [[ $containers_created -gt 0 ]]; then
        echo -e "
${CYAN}📋 Contenedores del laboratorio:${NC}"
        lxc list "^($(IFS='|'; echo "${CONTAINERS[*]}"))\$" --format table
        return 0
    else
        return 1
    fi
}

# Función para configurar IP estática
configure_static_ip() {
    local container_name="$1"
    local target_ip="$2"
    echo -e "${CYAN}   🌐 Configurando IP estática: $target_ip${NC}"

    # Configurar IP estática según la distribución
    lxc exec "$container_name" -- bash -c "
        # Detectar distribución
        if [ -f /etc/debian_version ]; then
            # Ubuntu/Debian
            cat > /etc/netplan/01-netcfg.yaml << 'NETEOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - $target_ip/24
      gateway4: 10.200.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
NETEOF
            netplan apply
        elif [ -f /etc/redhat-release ]; then
            # CentOS/RHEL/Fedora
            cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << 'NETEOF'
TYPE=Ethernet
BOOTPROTO=static
NAME=eth0
DEVICE=eth0
ONBOOT=yes
IPADDR=$target_ip
NETMASK=255.255.255.0
GATEWAY=10.200.1.1
DNS1=8.8.8.8
DNS2=1.1.1.1
NETEOF
            systemctl restart network 2>/dev/null || systemctl restart NetworkManager
        elif [ -f /etc/alpine-release ]; then
            # Alpine
            cat > /etc/network/interfaces << 'NETEOF'
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet static
    address $target_ip
    netmask 255.255.255.0
    gateway 10.200.1.1
    dns-nameservers 8.8.8.8 1.1.1.1
NETEOF
            /etc/init.d/networking restart
        fi
    " 2>/dev/null || echo -e "${YELLOW}   ⚠️  No se pudo configurar IP estática${NC}"
}

# Función para configurar SSH en contenedores
setup_container_ssh() {
    local container_name="$1"
    echo -e "${CYAN}   🔑 Configurando acceso SSH...${NC}"

    # Instalar y configurar SSH
    lxc exec "$container_name" -- bash -c "
        # Actualizar paquetes
        if command -v apt >/dev/null 2>&1; then
            apt update && apt install -y openssh-server python3 sudo
        elif command -v yum >/dev/null 2>&1; then
            yum install -y openssh-server python3 sudo
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y openssh-server python3 sudo
        elif command -v apk >/dev/null 2>&1; then
            apk add --no-cache openssh python3 sudo
        fi

        # Crear usuario ansible
        useradd -m -s /bin/bash ansible 2>/dev/null || true
        echo 'ansible:ansible123' | chpasswd
        usermod -aG sudo ansible 2>/dev/null || usermod -aG wheel ansible 2>/dev/null || true

        # Configurar sudoers
        echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible

        # Configurar SSH
        mkdir -p /home/ansible/.ssh
        chmod 700 /home/ansible/.ssh
        chown ansible:ansible /home/ansible/.ssh

        # Permitir autenticación por contraseña
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config

        # Iniciar SSH
        if command -v systemctl >/dev/null 2>&1; then
            systemctl enable ssh 2>/dev/null || systemctl enable sshd
            systemctl start ssh 2>/dev/null || systemctl start sshd
        elif command -v service >/dev/null 2>&1; then
            service ssh start 2>/dev/null || service sshd start
        fi
    " 2>/dev/null

    # Agregar clave pública si existe
    if [[ -f "$SSH_KEY_PATH.pub" ]]; then
        lxc exec "$container_name" -- bash -c "
            mkdir -p /home/ansible/.ssh
            echo '$(cat "$SSH_KEY_PATH.pub")' >> /home/ansible/.ssh/authorized_keys
            chmod 600 /home/ansible/.ssh/authorized_keys
            chown ansible:ansible /home/ansible/.ssh/authorized_keys
        " 2>/dev/null
    fi
}

# ========== 8. FUNCIONES DE PRUEBA ==========
# Función para probar conectividad SSH completa
test_ssh_connectivity() {
    log "INFO" "Probando conectividad SSH al laboratorio..."
    echo -e "
${BLUE}═══ PRUEBAS DE CONECTIVIDAD SSH ═══${NC}"
    if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No hay contenedores para probar${NC}"
        return 1
    fi

    local successful_connections=0
    local total_tests=${#CONTAINERS[@]}

    echo -e "${CYAN}Probando conectividad SSH a $total_tests contenedores...${NC}"
    echo ""

    for container in "${CONTAINERS[@]}"; do
        # Obtener IP del contenedor
        local container_ip=$(lxc exec "$container" -- ip -4 addr show eth0 | grep inet | awk '{print $2}' | cut -d'/' -f1 | head -1)
        if [[ -n "$container_ip" ]]; then
            echo -e "${CYAN}Probando SSH a $container ($container_ip)...${NC}"
            # Probar conexión SSH con clave
            if [[ -f "$SSH_KEY_PATH" ]]; then
                if timeout 10 ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ansible@"$container_ip" "echo 'SSH OK'" >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ SSH con clave: OK${NC}"
                    ((successful_connections++))
                else
                    # Probar con contraseña
                    if timeout 10 sshpass -p "ansible123" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ansible@"$container_ip" "echo 'SSH OK'" >/dev/null 2>&1; then
                        echo -e "${YELLOW}⚠️  SSH con contraseña: OK${NC}"
                        ((successful_connections++))
                    else
                        echo -e "${RED}❌ SSH: FALLO${NC}"
                    fi
                fi
            fi
        else
            echo -e "${RED}❌ $container: No se pudo obtener IP${NC}"
        fi
        echo ""
    done

    echo -e "${BLUE}═══ RESUMEN CONECTIVIDAD SSH ═══${NC}"
    echo -e "${GREEN}✅ Conexiones exitosas: $successful_connections/$total_tests${NC}"

    if [[ $successful_connections -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Función para probar Ansible
test_ansible_connectivity() {
    log "INFO" "Probando conectividad de Ansible..."
    echo -e "
${BLUE}═══ PRUEBAS DE ANSIBLE ═══${NC}"
    cd "$ANSIBLE_DIR"

    echo -e "${CYAN}Probando ping de Ansible a todos los hosts...${NC}"
    # Probar ping básico
    if ansible all -m ping --timeout=10; then
        echo -e "${GREEN}✅ Ping de Ansible: Exitoso${NC}"
        # Ejecutar gather facts
        echo -e "
${CYAN}Recopilando información del sistema...${NC}"
        ansible all -m setup -a "filter=ansible_distribution*" --timeout=15
        # Ejecutar playbook básico
        echo -e "
${CYAN}Ejecutando playbook de conectividad básica...${NC}"
        if ansible-playbook playbooks/ping.yml --timeout=20; then
            echo -e "${GREEN}✅ Playbook básico: Exitoso${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Playbook básico: Algunos problemas${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Ping de Ansible: Falló${NC}"
        echo -e "${YELLOW}Intentando diagnóstico...${NC}"
        # Diagnóstico básico
        echo -e "${CYAN}Verificando inventario:${NC}"
        ansible-inventory --list --yaml
        return 1
    fi
}

# ========== 9. FUNCIONES DE INFORMACIÓN Y DOCUMENTACIÓN ==========
# Función para mostrar información completa del laboratorio
show_lab_info() {
    log "INFO" "Mostrando información completa del laboratorio..."
    echo -e "
${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}${BOLD}                    INFORMACIÓN DEL LABORATORIO                       ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"

    # Información de LXD
    echo -e "
${CYAN}🔧 Información de LXD:${NC}"
    if command -v lxc >/dev/null 2>&1; then
        echo -e "${CYAN}Versión:${NC} $(lxd --version 2>/dev/null || echo 'Instalado')"
        echo -e "${CYAN}Storage Pools:${NC}"
        lxc storage list 2>/dev/null || echo "No disponible"
        echo -e "
${CYAN}Redes configuradas:${NC}"
        lxc network list 2>/dev/null || echo "No disponible"
    fi

    # Información de Ansible
    echo -e "
${CYAN}🤖 Información de Ansible:${NC}"
    if command -v ansible >/dev/null 2>&1; then
        echo -e "${CYAN}Versión:${NC} $(ansible --version | head -1 | cut -d' ' -f2)"
        echo -e "${CYAN}Directorio de laboratorio:${NC} $ANSIBLE_DIR"
        echo -e "${CYAN}Inventario:${NC} $INVENTORY_FILE"
        echo -e "${CYAN}Clave SSH:${NC} $SSH_KEY_PATH"
    fi

    # Lista de contenedores
    echo -e "
${CYAN}📦 Contenedores del laboratorio:${NC}"
    if [[ ${#CONTAINERS[@]} -gt 0 ]]; then
        lxc list "^($(IFS='|'; echo "${CONTAINERS[*]}"))\$" --format table 2>/dev/null || echo "Error obteniendo lista"

        # Información detallada de cada contenedor
        echo -e "
${CYAN}📋 Detalles de los contenedores:${NC}"
        printf "%-12s %-15s %-15s %-30s\n" "NOMBRE" "IP" "ESTADO" "DESCRIPCIÓN"
        echo "────────────────────────────────────────────────────────────────────────────"
        for machine_name in "${!LAB_MACHINES[@]}"; do
            if [[ " ${CONTAINERS[*]} " =~ " ${machine_name} " ]]; then
                IFS=':' read -r image ip description <<< "${LAB_MACHINES[$machine_name]}"
                local status=$(lxc info "$machine_name" 2>/dev/null | grep Status | awk '{print $2}' || echo "Unknown")
                printf "%-12s %-15s %-15s %-30s\n" "$machine_name" "$ip" "$status" "$description"
            fi
        done
    else
        echo -e "${RED}No hay contenedores creados${NC}"
    fi

    # Archivos importantes
    echo -e "
${CYAN}📁 Archivos importantes del laboratorio:${NC}"
    echo -e "${CYAN}├── Configuración:${NC} $ANSIBLE_DIR/ansible.cfg"
    echo -e "${CYAN}├── Inventario:${NC} $ANSIBLE_DIR/inventory"
    echo -e "${CYAN}├── Playbooks:${NC} $ANSIBLE_DIR/playbooks/"
    echo -e "${CYAN}├── Logs:${NC} $ANSIBLE_DIR/logs/"
    echo -e "${CYAN}├── Clave SSH:${NC} $SSH_KEY_PATH"
    echo -e "${CYAN}└── Log del script:${NC} $LOG_FILE"

    # Red del laboratorio
    echo -e "
${CYAN}🌐 Configuración de red:${NC}"
    echo -e "${CYAN}Red:${NC} $LAB_NETWORK ($LAB_SUBNET)"
    echo -e "${CYAN}Gateway:${NC} 10.200.1.1"
    echo -e "${CYAN}Rango DHCP:${NC} 10.200.1.10-10.200.1.100"

    # Recursos del sistema
    echo -e "
${CYAN}💻 Recursos del sistema host:${NC}"
    echo -e "${CYAN}CPU:${NC} $CPU_CORES cores"
    echo -e "${CYAN}RAM:${NC} ${RAM_TOTAL_GB}GB total, ${RAM_AVAILABLE_GB}GB disponible"
    echo -e "${CYAN}Almacenamiento:${NC} $BEST_STORAGE_PATH (${best_space}GB disponible)"
}

# Función para crear guía de uso
create_usage_guide() {
    local guide_file="$ANSIBLE_DIR/GUIA_DE_USO.md"
    echo -e "${CYAN}📚 Creando guía de uso del laboratorio...${NC}"
    cat > "$guide_file" << 'EOF'
# Guía de Uso del Laboratorio Ansible

## 🚀 Inicio Rápido
### 1. Activar el entorno
```bash
cd ~/ansible-lab
source ~/.bashrc  # Para cargar el PATH de Ansible
