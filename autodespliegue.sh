#!/bin/bash

# ============================================================================
# AUTOMATIZADOR DE ENTORNO DE DESARROLLO MULTI-DISTRO
# Soporta: Ubuntu, Debian, CentOS, RHEL, Fedora, openSUSE, Arch, Alpine, Oracle
# Autor: Cristian David Duran Grimaldo
# Versión: 2.1 - CARPETA EN /home/USUARIO/despliegues
# ============================================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Variables globales - ¡AHORA EN /home!
USER_HOME=$(eval echo ~$USER)
DEPLOY_BASE_DIR="$USER_HOME/despliegues"  # <-- CAMBIO IMPORTANTE: ahora en /home
PROJECT_NAME=""
PROJECT_TYPE=""
NODE_VERSION="20"
GIT_REPO=""
DISTRO=""
PACKAGE_MANAGER=""

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

print_header() {
    echo -e "${CYAN}"
    echo "============================================================================"
    echo "  🚀 AUTOMATIZADOR DE ENTORNO DE DESARROLLO"
    echo "  Multi-Distro Setup Script - Versión /home"
    echo "============================================================================"
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

# Detectar distribución de Linux
detect_distro() {
    print_step "Detectando distribución de Linux..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="rhel"
    elif [[ -f /etc/arch-release ]]; then
        DISTRO="arch"
    elif [[ -f /etc/alpine-release ]]; then
        DISTRO="alpine"
    else
        print_error "No se pudo detectar la distribución"
        exit 1
    fi
    
    # Normalizar nombres para Oracle Linux y openSUSE
    if [[ "$DISTRO" == "ol" ]]; then
        DISTRO="oracle"
    fi
    if [[ "$DISTRO" == "sles" ]] || [[ "$DISTRO" == "opensuse-tumbleweed" ]] || [[ "$DISTRO" == "opensuse-leap" ]]; then
        DISTRO="opensuse"
    fi
    
    # Determinar gestor de paquetes
    case $DISTRO in
        ubuntu|debian)
            PACKAGE_MANAGER="apt"
            ;;
        centos|rhel|fedora|oracle)
            if command -v dnf &> /dev/null; then
                PACKAGE_MANAGER="dnf"
            else
                PACKAGE_MANAGER="yum"
            fi
            ;;
        opensuse)
            PACKAGE_MANAGER="zypper"
            ;;
        arch|manjaro)
            PACKAGE_MANAGER="pacman"
            ;;
        alpine)
            PACKAGE_MANAGER="apk"
            ;;
        *)
            print_error "Distribución no soportada: $DISTRO"
            echo "Distribuciones soportadas: Ubuntu, Debian, CentOS, RHEL, Fedora, Oracle, openSUSE, Arch, Alpine"
            exit 1
            ;;
    esac
    
    print_success "Distribución detectada: $DISTRO (Gestor: $PACKAGE_MANAGER)"
}

# Actualizar sistema
update_system() {
    print_step "Actualizando sistema..."
    
    case $PACKAGE_MANAGER in
        apt)
            sudo apt update && sudo apt upgrade -y
            ;;
        dnf)
            sudo dnf update -y
            ;;
        yum)
            sudo yum update -y
            ;;
        zypper)
            sudo zypper refresh && sudo zypper update -y
            ;;
        pacman)
            sudo pacman -Syu --noconfirm
            ;;
        apk)
            sudo apk update && sudo apk upgrade
            ;;
    esac
    
    print_success "Sistema actualizado"
}

# Instalar dependencias básicas
install_basic_deps() {
    print_step "Instalando dependencias básicas..."
    
    case $PACKAGE_MANAGER in
        apt)
            sudo apt install -y curl wget git build-essential software-properties-common \
                             apt-transport-https ca-certificates gnupg lsb-release unzip
            ;;
        dnf)
            sudo dnf groupinstall -y "Development Tools"
            sudo dnf install -y curl wget git gcc gcc-c++ make unzip
            ;;
        yum)
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y curl wget git gcc gcc-c++ make unzip
            ;;
        zypper)
            sudo zypper install -y curl wget git gcc gcc-c++ make unzip \
                                 patterns-devel-base-devel_basis
            ;;
        pacman)
            sudo pacman -S --noconfirm curl wget git base-devel unzip
            ;;
        apk)
            sudo apk add curl wget git build-base unzip
            ;;
    esac
    
    print_success "Dependencias básicas instaladas"
}

# Verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Instalar Node.js usando NodeSource
install_nodejs() {
    if command_exists node; then
        local current_version=$(node --version 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ $current_version -ge $NODE_VERSION ]]; then
            print_success "Node.js ya está instalado (v$(node --version))"
            return 0
        else
            print_warning "Node.js versión actual (v$(node --version)) es menor que la requerida (v$NODE_VERSION)"
        fi
    fi
    
    print_step "Instalando Node.js v$NODE_VERSION..."
    
    case $PACKAGE_MANAGER in
        apt)
            curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        dnf|yum)
            curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | sudo bash -
            sudo $PACKAGE_MANAGER install -y nodejs
            ;;
        zypper)
            curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | sudo bash -
            sudo zypper install -y nodejs
            ;;
        pacman)
            sudo pacman -S --noconfirm nodejs npm
            ;;
        apk)
            sudo apk add nodejs npm
            ;;
    esac
    
    if command_exists node; then
        print_success "Node.js instalado: $(node --version)"
        print_success "NPM instalado: $(npm --version)"
    else
        print_error "Error al instalar Node.js"
        exit 1
    fi
}

# Instalar Yarn
install_yarn() {
    if command_exists yarn; then
        print_success "Yarn ya está instalado ($(yarn --version))"
        return
    fi
    
    print_step "Instalando Yarn..."
    npm install -g yarn
    if command_exists yarn; then
        print_success "Yarn instalado: $(yarn --version)"
    else
        print_warning "No se pudo instalar Yarn globalmente, usando npm como alternativa"
    fi
}

# Instalar PM2
install_pm2() {
    if command_exists pm2; then
        print_success "PM2 ya está instalado"
        return
    fi
    
    print_step "Instalando PM2..."
    npm install -g pm2
    if command_exists pm2; then
        print_success "PM2 instalado"
    else
        print_warning "No se pudo instalar PM2 globalmente"
    fi
}

# Crear estructura de directorios - ¡AHORA EN /home!
create_project_structure() {
    print_step "Creando estructura de directorios en $DEPLOY_BASE_DIR..."
    
    # Crear directorio base si no existe (sin sudo, es en /home)
    if [[ ! -d "$DEPLOY_BASE_DIR" ]]; then
        mkdir -p "$DEPLOY_BASE_DIR"
        print_success "Directorio base creado: $DEPLOY_BASE_DIR"
    fi
    
    # Crear directorio del proyecto
    PROJECT_DIR="$DEPLOY_BASE_DIR/$PROJECT_NAME"
    
    if [[ -d "$PROJECT_DIR" ]]; then
        print_warning "El proyecto '$PROJECT_NAME' ya existe en $PROJECT_DIR"
        read -p "¿Deseas continuar y sobrescribir? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Operación cancelada"
            exit 1
        fi
        rm -rf "$PROJECT_DIR"
    fi
    
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Crear estructura común a todos los proyectos
    mkdir -p templates
    mkdir -p static/{css,js,images,fonts}
    mkdir -p logs
    mkdir -p config
    
    # Crear estructura según el tipo de proyecto
    case $PROJECT_TYPE in
        "react")
            print_step "Creando estructura para React..."
            mkdir -p {src/{components,pages,hooks,utils,styles},public,build}
            ;;
        "vue")
            print_step "Creando estructura para Vue..."
            mkdir -p {src/{components,views,store,router,assets},public,dist}
            ;;
        "angular")
            print_step "Creando estructura para Angular..."
            mkdir -p {src/{app,assets,environments},dist}
            ;;
        "express"|"node")
            print_step "Creando estructura para Node.js/Express..."
            mkdir -p {src/{controllers,models,routes,middleware,utils},public}
            ;;
        "nextjs")
            print_step "Creando estructura para Next.js..."
            mkdir -p {pages,components,styles,public,lib}
            ;;
        "custom")
            print_step "Creando estructura personalizada..."
            mkdir -p {src,dist,public,docs}
            ;;
    esac
    
    print_success "Estructura creada en: $PROJECT_DIR"
    print_success "Carpetas clave: /templates, /static/css, /static/js, /static/images"
}

# Clonar repositorio si se proporciona
clone_repository() {
    if [[ -n "$GIT_REPO" ]]; then
        if ! command_exists git; then
            print_error "Git no está instalado. Instálalo primero."
            return 1
        fi
        
        print_step "Clonando repositorio: $GIT_REPO"
        
        # Clonar en directorio temporal y mover archivos
        TEMP_DIR="/tmp/${PROJECT_NAME}_clone_$(date +%s)"
        git clone "$GIT_REPO" "$TEMP_DIR"
        
        if [[ $? -eq 0 ]]; then
            # Mover archivos del repositorio al directorio del proyecto
            shopt -s dotglob  # Incluir archivos ocultos
            mv "$TEMP_DIR"/* "$PROJECT_DIR/" 2>/dev/null || true
            mv "$TEMP_DIR"/.* "$PROJECT_DIR/" 2>/dev/null || true
            shopt -u dotglob
            rm -rf "$TEMP_DIR"
            print_success "Repositorio clonado exitosamente"
        else
            print_error "Error al clonar el repositorio"
            return 1
        fi
    fi
}

# Configurar proyecto Node.js
setup_nodejs_project() {
    cd "$PROJECT_DIR"
    
    if [[ ! -f "package.json" ]]; then
        print_step "Inicializando proyecto Node.js..."
        npm init -y
        
        # Actualizar package.json con información básica
        cat > package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "Proyecto creado con automatizador de entorno",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "build": "echo 'Build script here'",
    "test": "echo 'Test script here'"
  },
  "keywords": [],
  "author": "",
  "license": "ISC"
}
EOF
    fi
    
    # Instalar dependencias según el tipo de proyecto
    case $PROJECT_TYPE in
        "react")
            print_step "Configurando proyecto React..."
            if [[ ! -d "node_modules" ]]; then
                npx create-react-app . --template typescript
            fi
            ;;
        "vue")
            print_step "Configurando proyecto Vue..."
            if [[ ! -d "node_modules" ]]; then
                npm install -g @vue/cli
                vue create . --preset default --no-git
            fi
            ;;
        "express"|"node")
            print_step "Instalando dependencias de Express..."
            npm install express cors helmet morgan dotenv
            npm install -D nodemon
            
            # Crear archivo básico de Express
            if [[ ! -f "index.js" ]]; then
                cat > index.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middlewares
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static files - ¡RUTA CORRECTA PARA /static!
app.use('/static', express.static('static'));

// Routes
app.get('/', (req, res) => {
    res.json({ message: 'API funcionando correctamente' });
});

app.get('/health', (req, res) => {
    res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Error handler
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Algo salió mal!' });
});

app.listen(PORT, () => {
    console.log(`Servidor corriendo en puerto ${PORT}`);
});
EOF
            fi
            ;;
        "nextjs")
            print_step "Configurando proyecto Next.js..."
            if [[ ! -d "node_modules" ]]; then
                npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir
            fi
            ;;
    esac
    
    print_success "Proyecto Node.js configurado"
}

# Crear archivos de configuración
create_config_files() {
    cd "$PROJECT_DIR"
    
    # .env file
    if [[ ! -f ".env" ]]; then
        cat > .env << EOF
# Configuración del entorno
NODE_ENV=development
PORT=3000
HOST=localhost

# Rutas de archivos estáticos
STATIC_PATH=./static
TEMPLATES_PATH=./templates

# Base de datos
# DB_HOST=localhost
# DB_PORT=5432
# DB_NAME=${PROJECT_NAME}_db
# DB_USER=postgres
# DB_PASSWORD=password

# JWT Secret
# JWT_SECRET=tu_jwt_secret_aqui

# API Keys
# API_KEY=tu_api_key_aqui
EOF
    fi
    
    # .gitignore
    if [[ ! -f ".gitignore" ]]; then
        cat > .gitignore << 'EOF'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/
.nyc_output

# Grunt intermediate storage
.grunt

# node-waf configuration
.lock-wscript

# Compiled binary addons
build/Release

# Dependency directories
jspm_packages/

# Optional npm cache directory
.npm

# Optional eslint cache
.eslintcache

# Output of 'npm pack'
*.tgz

# Yarn Integrity file
.yarn-integrity

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
logs
*.log

# Build directories
dist/
build/

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Archivos de configuración generados
ecosystem.config.js
nginx.conf
EOF
    fi
    
    # PM2 ecosystem file
    cat > ecosystem.config.js << EOF
module.exports = {
  apps: [
    {
      name: '$PROJECT_NAME',
      script: 'index.js',
      instances: 'max',
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'development',
        PORT: 3000,
        STATIC_PATH: './static',
        TEMPLATES_PATH: './templates'
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 8000,
        STATIC_PATH: './static',
        TEMPLATES_PATH: './templates'
      },
      log_file: './logs/combined.log',
      out_file: './logs/out.log',
      error_file: './logs/error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true
    }
  ]
};
EOF
    
    # README.md
    if [[ ! -f "README.md" ]]; then
        cat > README.md << EOF
# $PROJECT_NAME

Proyecto creado con el automatizador de entorno de desarrollo.

## 📁 Estructura del proyecto
- \`/templates\` - Plantillas (HTML, EJS, Handlebars, etc.)
- \`/static\` - Archivos estáticos
  - \`/static/css\` - Hojas de estilo
  - \`/static/js\` - JavaScript
  - \`/static/images\` - Imágenes
  - \`/static/fonts\` - Fuentes
- \`/src\` - Código fuente
- \`/config\` - Configuraciones
- \`/logs\` - Archivos de log

## 🚀 Instalación

\`\`\`bash
npm install
\`\`\`

## 🛠 Desarrollo

\`\`\`bash
npm run dev
\`\`\`

## 🏭 Producción

\`\`\`bash
npm start
\`\`\`

## 🐳 Con PM2

\`\`\`bash
pm2 start ecosystem.config.js --env production
\`\`\`

## ⚙ Variables de entorno

Copia \`.env.example\` a \`.env\` y configura las variables necesarias.

## 📍 Ubicación
Proyecto ubicado en: \`$PROJECT_DIR\`
EOF
    fi
    
    print_success "Archivos de configuración creados"
    print_success "Estructura completa con /templates y /static/{css,js,images,fonts}"
}

# Configurar servicios adicionales
setup_additional_services() {
    print_step "¿Deseas instalar servicios adicionales?"
    echo "1) Nginx"
    echo "2) Docker"
    echo "3) PostgreSQL"
    echo "4) MongoDB"
    echo "5) Redis"
    echo "6) Todos los anteriores"
    echo "7) Ninguno"
    
    read -p "Selecciona una opción (1-7): " service_option
    
    case $service_option in
        1|6)
            install_nginx
            ;;
        2|6)
            install_docker
            ;;
        3|6)
            install_postgresql
            ;;
        4|6)
            install_mongodb
            ;;
        5|6)
            install_redis
            ;;
        7)
            print_step "Saltando instalación de servicios adicionales"
            ;;
        *)
            print_warning "Opción no válida, saltando servicios adicionales"
            ;;
    esac
}

# Instalar Nginx
install_nginx() {
    if command_exists nginx; then
        print_success "Nginx ya está instalado"
        return
    fi
    
    print_step "Instalando Nginx..."
    
    case $PACKAGE_MANAGER in
        apt)
            sudo apt install -y nginx
            ;;
        dnf|yum)
            sudo $PACKAGE_MANAGER install -y nginx
            ;;
        zypper)
            sudo zypper install -y nginx
            ;;
        pacman)
            sudo pacman -S --noconfirm nginx
            ;;
        apk)
            sudo apk add nginx
            ;;
    esac
    
    # Configurar Nginx para el proyecto
    NGINX_CONF="/tmp/${PROJECT_NAME}.nginx"
    cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    server_name ${PROJECT_NAME}.local localhost;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Ruta para archivos estáticos - ¡IMPORTANTE!
    location /static/ {
        alias $PROJECT_DIR/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Ruta para imágenes específicas
    location ~* \.(jpg|jpeg|png|gif|ico|svg)$ {
        root $PROJECT_DIR/static/images;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Ruta para CSS y JS
    location ~* \.(css|js)$ {
        root $PROJECT_DIR/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    print_success "Nginx instalado. Configuración disponible en: $NGINX_CONF"
    print_warning "Para activar: sudo cp $NGINX_CONF /etc/nginx/sites-available/ && sudo ln -s /etc/nginx/sites-available/$(basename $NGINX_CONF) /etc/nginx/sites-enabled/ && sudo systemctl reload nginx"
}

# Instalar Docker
install_docker() {
    if command_exists docker; then
        print_success "Docker ya está instalado"
        return
    fi
    
    print_step "Instalando Docker..."
    
    case $PACKAGE_MANAGER in
        apt)
            # Verificar si estamos en Ubuntu/Debian
            if [[ "$DISTRO" == "ubuntu" ]] || [[ "$DISTRO" == "debian" ]]; then
                curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt update
                sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            else
                sudo apt install -y docker.io
            fi
            ;;
        dnf)
            sudo dnf install -y docker-ce docker-ce-cli containerd.io
            ;;
        yum)
            sudo yum install -y docker
            ;;
        zypper)
            sudo zypper install -y docker
            ;;
        pacman)
            sudo pacman -S --noconfirm docker
            ;;
        apk)
            sudo apk add docker docker-compose
            ;;
    esac
    
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    
    # Crear Dockerfile básico
    cd "$PROJECT_DIR"
    if [[ ! -f "Dockerfile" ]]; then
        cat > Dockerfile << EOF
FROM node:${NODE_VERSION}-alpine

WORKDIR /app

# Copiar package.json primero para aprovechar la caché
COPY package*.json ./
RUN npm ci --only=production

# Copiar el resto de la aplicación
COPY . .

# Exponer puerto
EXPOSE 3000

# Crear usuario no root para mayor seguridad
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001
USER nextjs

# Comando de inicio
CMD ["npm", "start"]
EOF
    fi
    
    # Docker Compose
    if [[ ! -f "docker-compose.yml" ]]; then
        cat > docker-compose.yml << EOF
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - STATIC_PATH=./static
      - TEMPLATES_PATH=./templates
    volumes:
      - ./logs:/app/logs
      - ./static:/app/static
      - ./templates:/app/templates
    restart: unless-stopped
    user: "1001:1001"

  # Descomenta para agregar Nginx como proxy inverso
  # nginx:
  #   image: nginx:alpine
  #   ports:
  #     - "80:80"
  #   volumes:
  #     - ./nginx.conf:/etc/nginx/nginx.conf
  #   depends_on:
  #     - app
  #   restart: unless-stopped
EOF
    fi
    
    print_success "Docker instalado y configurado"
    print_warning "Recuerda cerrar y volver a iniciar sesión para usar Docker sin sudo"
}

# Instalar PostgreSQL
install_postgresql() {
    print_step "Instalando PostgreSQL..."
    
    case $PACKAGE_MANAGER in
        apt)
            sudo apt install -y postgresql postgresql-contrib
            ;;
        dnf)
            sudo dnf install -y postgresql-server postgresql-contrib
            sudo postgresql-setup --initdb
            ;;
        yum)
            sudo yum install -y postgresql-server postgresql-contrib
            sudo postgresql-setup initdb
            ;;
        zypper)
            sudo zypper install -y postgresql postgresql-contrib
            ;;
        pacman)
            sudo pacman -S --noconfirm postgresql
            ;;
        apk)
            sudo apk add postgresql postgresql-contrib
            ;;
    esac
    
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
    
    print_success "PostgreSQL instalado y en ejecución"
}

# Instalar MongoDB
install_mongodb() {
    print_step "Instalando MongoDB..."
    
    case $PACKAGE_MANAGER in
        apt)
            curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-archive-keyring.gpg
            echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
            sudo apt update
            sudo apt install -y mongodb-org
            ;;
        dnf|yum)
            cat <<EOF | sudo tee /etc/yum.repos.d/mongodb-org-6.0.repo
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF
            sudo $PACKAGE_MANAGER install -y mongodb-org
            ;;
        zypper)
            print_warning "MongoDB no disponible directamente en openSUSE. Considera usar Docker."
            return
            ;;
        pacman)
            sudo pacman -S --noconfirm mongodb
            ;;
        apk)
            sudo apk add mongodb
            ;;
    esac
    
    if [[ -f /etc/systemd/system/mongod.service ]]; then
        sudo systemctl enable mongod
        sudo systemctl start mongod
    else
        sudo systemctl enable mongodb
        sudo systemctl start mongodb
    fi
    
    print_success "MongoDB instalado y en ejecución"
}

# Instalar Redis
install_redis() {
    print_step "Instalando Redis..."
    
    case $PACKAGE_MANAGER in
        apt)
            sudo apt install -y redis-server
            ;;
        dnf|yum)
            sudo $PACKAGE_MANAGER install -y redis
            ;;
        zypper)
            sudo zypper install -y redis
            ;;
        pacman)
            sudo pacman -S --noconfirm redis
            ;;
        apk)
            sudo apk add redis
            ;;
    esac
    
    sudo systemctl enable redis
    sudo systemctl start redis
    
    print_success "Redis instalado y en ejecución"
}

# Mostrar resumen final
show_summary() {
    echo -e "${CYAN}"
    echo "============================================================================"
    echo "  🎉 ¡RESUMEN DE INSTALACIÓN COMPLETADO!"
    echo "============================================================================"
    echo -e "${NC}"
    
    echo -e "${GREEN}✓ Proyecto:${NC} $PROJECT_NAME"
    echo -e "${GREEN}✓ Tipo:${NC} $PROJECT_TYPE"
    echo -e "${GREEN}✓ Ubicación:${NC} $PROJECT_DIR"
    echo -e "${GREEN}✓ Distribución:${NC} $DISTRO"
    echo -e "${GREEN}✓ Node.js:${NC} $(node --version 2>/dev/null || echo 'No instalado')"
    echo -e "${GREEN}✓ NPM:${NC} $(npm --version 2>/dev/null || echo 'No instalado')"
    echo -e "${GREEN}✓ Git:${NC} $(git --version 2>/dev/null | cut -d' ' -f3 || echo 'No instalado')"
    
    echo -e "\n${YELLOW}📁 Estructura de carpetas:${NC}"
    echo "  $PROJECT_DIR/"
    echo "  ├── templates/"
    echo "  ├── static/"
    echo "  │   ├── css/"
    echo "  │   ├── js/"
    echo "  │   ├── images/"
    echo "  │   └── fonts/"
    echo "  ├── src/"
    echo "  ├── config/"
    echo "  └── logs/"
    
    echo -e "\n${YELLOW}🚀 Comandos útiles:${NC}"
    echo "  cd $PROJECT_DIR"
    echo "  npm install          # Instalar dependencias"
    echo "  npm run dev          # Modo desarrollo"
    echo "  npm start            # Modo producción"
    echo "  pm2 start ecosystem.config.js --env production"
    
    if [[ -n "$GIT_REPO" ]]; then
        echo -e "\n${BLUE}🔗 Repositorio clonado desde:${NC} $GIT_REPO"
    fi
    
    echo -e "\n${PURPLE}📄 Archivos clave creados:${NC}"
    echo "  - package.json"
    echo "  - .env (configurar variables)"
    echo "  - .gitignore"
    echo "  - ecosystem.config.js (PM2)"
    echo "  - README.md"
    if [[ -f "$PROJECT_DIR/Dockerfile" ]]; then
        echo "  - Dockerfile"
        echo "  - docker-compose.yml"
    fi
    
    echo -e "\n${GREEN}🎉 ¡Entorno configurado exitosamente en /home!${NC}"
    echo -e "${YELLOW}💡 Tip:${NC} Usa 'code $PROJECT_DIR' para abrir en VS Code"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    print_header
    
    # Verificar que se ejecuta como usuario normal (no root)
    if [[ $EUID -eq 0 ]]; then
        print_error "No ejecutes este script como root. Usa tu usuario normal."
        exit 1
    fi
    
    # Detectar distribución
    detect_distro
    
    # Solicitar información del proyecto
    echo -e "\n${YELLOW}📝 Configuración del proyecto:${NC}"
    
    while [[ -z "$PROJECT_NAME" ]]; do
        read -p "Nombre del proyecto: " PROJECT_NAME
        if [[ -z "$PROJECT_NAME" ]]; then
            print_error "El nombre del proyecto es obligatorio"
        fi
    done
    
    echo -e "\n${CYAN}Tipos de proyecto disponibles:${NC}"
    echo "1) React"
    echo "2) Vue.js"
    echo "3) Angular"
    echo "4) Express/Node.js"
    echo "5) Next.js"
    echo "6) Personalizado"
    
    read -p "Selecciona el tipo de proyecto (1-6): " project_type_choice
    
    case $project_type_choice in
        1) PROJECT_TYPE="react" ;;
        2) PROJECT_TYPE="vue" ;;
        3) PROJECT_TYPE="angular" ;;
        4) PROJECT_TYPE="express" ;;
        5) PROJECT_TYPE="nextjs" ;;
        6) PROJECT_TYPE="custom" ;;
        *)
            print_warning "Opción inválida, usando tipo personalizado"
            PROJECT_TYPE="custom"
            ;;
    esac
    
    read -p "URL del repositorio Git (opcional, presiona Enter para omitir): " GIT_REPO
    
    read -p "Versión de Node.js [$NODE_VERSION]: " node_version_input
    if [[ -n "$node_version_input" ]] && [[ "$node_version_input" =~ ^[0-9]+$ ]]; then
        NODE_VERSION=$node_version_input
    fi
    
    read -p "Directorio base [$DEPLOY_BASE_DIR]: " deploy_dir_input
    if [[ -n "$deploy_dir_input" ]]; then
        DEPLOY_BASE_DIR="$deploy_dir_input"
    fi
    
    # Confirmación
    echo -e "\n${YELLOW}📋 Configuración final:${NC}"
    echo "  - Proyecto: $PROJECT_NAME"
    echo "  - Tipo: $PROJECT_TYPE"
    echo "  - Node.js: v$NODE_VERSION"
    echo "  - Directorio: $DEPLOY_BASE_DIR/$PROJECT_NAME"
    if [[ -n "$GIT_REPO" ]]; then
        echo "  - Repositorio: $GIT_REPO"
    fi
    
    read -p $'\n¿Continuar con la instalación? (Y/n): ' -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_error "Instalación cancelada"
        exit 1
    fi
    
    # Proceso de instalación
    echo -e "\n${CYAN}🚀 Iniciando proceso de instalación...${NC}"
    
    update_system
    install_basic_deps
    install_nodejs
    install_yarn
    install_pm2
    
    create_project_structure
    clone_repository
    setup_nodejs_project
    create_config_files
    
    # Preguntar por servicios adicionales
    setup_additional_services
    
    # Resumen final
    show_summary
    
    # Mensaje final
    echo -e "\n${GREEN}✨ ¡Todo listo! Tu proyecto está configurado en: ${NC}"
    echo -e "${BLUE}$PROJECT_DIR${NC}"
    echo -e "\n${YELLOW}💡 Para comenzar:${NC}"
    echo "  cd $PROJECT_DIR"
    echo "  npm install"
    echo "  npm run dev"
    
    if command_exists docker && groups $USER | grep -q docker; then
        echo -e "\n${YELLOW}📌 Nota:${NC} Para usar Docker sin sudo, cierra sesión y vuelve a iniciarla."
    fi
}

# Manejo de errores
trap 'print_error "Script interrumpido por el usuario"; exit 1' INT
trap 'print_error "Error en la línea $LINENO"; exit 1' ERR

# Ejecutar función principal
main "$@"
