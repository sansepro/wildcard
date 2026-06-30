#!/bin/bash

# Генератор Wildcard SSL Сертификатов - Скрипт установки
# Для систем Ubuntu/Debian
# Установка: bash <(wget -qO- https://raw.githubusercontent.com/sansepro/wildcard/main/install.sh)

set -e

# Цвета с правильной интерпретацией
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

# Дефолт значения
INSTALL_DIR="/opt/certbot"
EMAIL=""
CLOUDFLARE_API_TOKEN=""
DOMAIN=""
PRIMARY_DOMAIN=""
SKIP_DOCKER_CHECK=false
AUTO_YES=false
SKIP_CRON=false
QUIET=false

# Функция помощи
show_help() {
    cat << EOF
${BLUE}Использование:${NC}
bash install.sh [опции]

${BLUE}Основные параметры:${NC}
  -e, --email EMAIL                    Email для Let's Encrypt
  -t, --token TOKEN                    Cloudflare API Token
  -d, --domain DOMAIN                  Домены (например: *.example.com,example.com)
  -p, --primary DOMAIN                 Основной домен (например: example.com)

${BLUE}Дополнительные параметры:${NC}
  -i, --install-dir DIR                Директория установки (дефолт: /opt/certbot)
  -y, --yes                            Ответить 'да' на все вопросы
  -q, --quiet                          Минимальный вывод
  --skip-docker-check                  Пропустить проверку Docker
  --skip-cron                          Пропустить настройку cron

${BLUE}Другое:${NC}
  -h, --help                           Показать эту справку

${BLUE}Примеры:${NC}
  bash install.sh
  bash install.sh -e admin@example.com -t token123 -d '*.example.com,example.com' -p example.com
  bash install.sh -e admin@example.com -t token123 -d '*.example.com,example.com' -p example.com -y -q
EOF
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -t|--token)
            CLOUDFLARE_API_TOKEN="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -p|--primary)
            PRIMARY_DOMAIN="$2"
            shift 2
            ;;
        -i|--install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --skip-docker-check)
            SKIP_DOCKER_CHECK=true
            shift
            ;;
        --skip-cron)
            SKIP_CRON=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Неизвестная опция: $1"
            show_help
            exit 1
            ;;
    esac
done

# Вспомогательные функции
print_header() {
    if [ "$QUIET" = true ]; then
        return
    fi
    echo
    echo "${BLUE}════════════════════════════════════════${NC}"
    echo "${BLUE}$1${NC}"
    echo "${BLUE}════════════════════════════════════════${NC}"
    echo
}

print_step() {
    if [ "$QUIET" = true ]; then
        return
    fi
    echo "${BLUE}➜${NC} $1"
}

print_success() {
    if [ "$QUIET" = true ]; then
        return
    fi
    echo "${GREEN}✓${NC} $1"
}

print_error() {
    echo "${RED}✗${NC} $1"
}

run_command() {
    local message=$1
    local command=$2
    
    print_step "$message"
    
    if bash -c "$command" > /tmp/install_log.txt 2>&1; then
        print_success "$message"
    else
        print_error "$message не удалась"
        cat /tmp/install_log.txt
        exit 1
    fi
}

check_docker() {
    if [ "$SKIP_DOCKER_CHECK" = true ]; then
        print_success "Проверка Docker пропущена"
        return
    fi
    
    if ! command -v docker &> /dev/null; then
        print_step "Установка Docker..."
        if curl -fsSL https://get.docker.com | sh > /tmp/install_log.txt 2>&1; then
            print_success "Docker установлен"
        else
            print_error "Не удалось установить Docker"
            cat /tmp/install_log.txt
            exit 1
        fi
    else
        print_success "Docker найден: $(docker --version | awk '{print $3}')"
    fi
}

create_generate_dockerfile() {
    mkdir -p "$INSTALL_DIR/generate"
    cat > "$INSTALL_DIR/generate/Dockerfile" << 'EOF'
FROM certbot/dns-cloudflare:latest

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
EOF
    print_success "Dockerfile для создания создан"
}

create_renew_dockerfile() {
    mkdir -p "$INSTALL_DIR/renew"
    cat > "$INSTALL_DIR/renew/Dockerfile" << 'EOF'
FROM certbot/dns-cloudflare:latest

COPY ./renew.sh /renew.sh
RUN chmod +x /renew.sh

ENTRYPOINT ["/renew.sh"]
EOF
    print_success "Dockerfile для продления создан"
}

create_docker_compose() {
    cat > "$INSTALL_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  certbot-generate:
    build: ./generate
    container_name: certbot-generator
    env_file: .env
    volumes:
      - ./letsencrypt:/etc/letsencrypt
      - ./cert:/certificates
    restart: "no"
    
  certbot-renew:
    build: ./renew
    container_name: certbot-renewer
    env_file: .env
    volumes:
      - ./letsencrypt:/etc/letsencrypt
      - ./cert:/certificates
    restart: "no"
EOF
    print_success "docker-compose.yml создан"
}

create_generate_entrypoint() {
    mkdir -p "$INSTALL_DIR/generate"
    cat > "$INSTALL_DIR/generate/entrypoint.sh" << 'EOF'
#!/bin/sh

set -e

# Создание файла учетных данных Cloudflare
echo "dns_cloudflare_api_token=${CLOUDFLARE_API_TOKEN}" > /cloudflare.ini
chmod 600 /cloudflare.ini

# Получение wildcard SSL сертификата используя Certbot
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /cloudflare.ini \
  --dns-cloudflare-propagation-seconds 120 \
  -d "${DOMAIN}" \
  --non-interactive \
  --expand \
  --agree-tos \
  -m "${EMAIL}"

# Перемещение сертификатов в постоянное хранилище
mkdir -p /certificates/"${PRIMARY_DOMAIN}"

cp /etc/letsencrypt/live/"${PRIMARY_DOMAIN}"/fullchain.pem /certificates/"${PRIMARY_DOMAIN}"/chain.crt
cp /etc/letsencrypt/live/"${PRIMARY_DOMAIN}"/privkey.pem /certificates/"${PRIMARY_DOMAIN}"/privkey.key

# Создание конфигурации для Traefik
echo "tls:" > /certificates/"${PRIMARY_DOMAIN}"/certificate.yml
echo "  certificates:" >> /certificates/"${PRIMARY_DOMAIN}"/certificate.yml
echo "    - certFile: ${BASE_CERT_PATH}/${PRIMARY_DOMAIN}/chain.crt" >> /certificates/"${PRIMARY_DOMAIN}"/certificate.yml
echo "      keyFile: ${BASE_CERT_PATH}/${PRIMARY_DOMAIN}/privkey.key" >> /certificates/"${PRIMARY_DOMAIN}"/certificate.yml
EOF
    chmod +x "$INSTALL_DIR/generate/entrypoint.sh"
    print_success "entrypoint.sh для создания создан"
}

create_renew_script() {
    mkdir -p "$INSTALL_DIR/renew"
    cat > "$INSTALL_DIR/renew/renew.sh" << 'EOF'
#!/bin/sh

set -e

# Создание файла учетных данных Cloudflare
echo "dns_cloudflare_api_token=${CLOUDFLARE_API_TOKEN}" > /cloudflare.ini
chmod 600 /cloudflare.ini

# Обновление сертификата
certbot renew \
  --dns-cloudflare \
  --dns-cloudflare-credentials /cloudflare.ini \
  --dns-cloudflare-propagation-seconds 120 \
  --non-interactive

# Копирование обновленных сертификатов
mkdir -p /certificates/"${PRIMARY_DOMAIN}"

cp /etc/letsencrypt/live/"${PRIMARY_DOMAIN}"/fullchain.pem /certificates/"${PRIMARY_DOMAIN}"/chain.crt
cp /etc/letsencrypt/live/"${PRIMARY_DOMAIN}"/privkey.pem /certificates/"${PRIMARY_DOMAIN}"/privkey.key

echo "Сертификат обновлен: $(date)" >> /certificates/"${PRIMARY_DOMAIN}"/renewal.log
EOF
    chmod +x "$INSTALL_DIR/renew/renew.sh"
    print_success "renew.sh для продления создан"
}

load_env() {
    if [ -f "$INSTALL_DIR/.env" ]; then
        set -a
        source "$INSTALL_DIR/.env"
        set +a
        return 0
    fi
    return 1
}

create_config() {
    if [ -z "$EMAIL" ] || [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$DOMAIN" ] || [ -z "$PRIMARY_DOMAIN" ]; then
        if [ "$AUTO_YES" = false ]; then
            echo
            print_step "Настройка конфигурации..."
            echo
            
            if [ -z "$EMAIL" ]; then
                read -r -p "Email для Let's Encrypt: " EMAIL
            fi
            
            if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
                read -r -s -p "API токен Cloudflare: " CLOUDFLARE_API_TOKEN
                echo
            fi
            
            if [ -z "$DOMAIN" ]; then
                read -r -p "Домен(ы) (например: *.example.com,example.com): " DOMAIN
            fi
            
            if [ -z "$PRIMARY_DOMAIN" ]; then
                read -r -p "Основной домен (например: example.com): " PRIMARY_DOMAIN
            fi
        fi
    fi
    
    if [ -z "$EMAIL" ] || [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$DOMAIN" ] || [ -z "$PRIMARY_DOMAIN" ]; then
        print_error "Все поля обязательны"
        exit 1
    fi
    
    cat > "$INSTALL_DIR/.env" << EOF
EMAIL="$EMAIL"
CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN"
DOMAIN="$DOMAIN"
PRIMARY_DOMAIN="$PRIMARY_DOMAIN"
BASE_CERT_PATH="/certificates"
EOF
    
    chmod 600 "$INSTALL_DIR/.env"
    print_success ".env файл создан (права доступа: 600)"
    echo
}

setup_cron() {
    if [ "$SKIP_CRON" = true ]; then
        print_success "Настройка cron пропущена"
        return
    fi
    
    local cron_job="0 5 * * * cd $INSTALL_DIR && docker compose run --rm certbot-renew > /tmp/certbot_cron.log 2>&1"
    local cron_exists=$(crontab -l 2>/dev/null | grep -F "$INSTALL_DIR" || true)
    
    if [ -z "$cron_exists" ]; then
        (crontab -l 2>/dev/null || echo "") | grep -v "$INSTALL_DIR" | crontab - 2>/dev/null || true
        (crontab -l 2>/dev/null || echo ""; echo "$cron_job") | crontab -
        print_success "Cron job добавлен (05:00 каждый день)"
    else
        print_success "Cron job уже настроен"
    fi
}

# Основной процесс
main() {
    print_header "Генератор Wildcard SSL Сертификатов"
    
    # Создание директории
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
        chown $USER:$USER "$INSTALL_DIR"
    fi
    
    cd "$INSTALL_DIR"
    
    # Проверка Docker
    print_step "Проверка предварительных условий..."
    check_docker
    print_success "Все предварительные условия выполнены"
    echo
    
    # Создание необходимых файлов если их нет
    print_step "Настройка файлов проекта..."
    echo
    [ ! -f docker-compose.yml ] && create_docker_compose
    [ ! -f generate/Dockerfile ] && create_generate_dockerfile
    [ ! -f renew/Dockerfile ] && create_renew_dockerfile
    [ ! -f generate/entrypoint.sh ] && create_generate_entrypoint
    [ ! -f renew/renew.sh ] && create_renew_script
    
    # Проверка существующей конфигурации
    if load_env; then
        print_success "Найдена существующая конфигурация"
        echo
    else
        create_config
    fi
    
    # Отображение конфигурации
    if [ "$AUTO_YES" = false ]; then
        print_step "Текущая конфигурация:"
        echo "  Email: ${GREEN}$EMAIL${NC}"
        echo "  Домены: ${GREEN}$DOMAIN${NC}"
        echo "  Основной домен: ${GREEN}$PRIMARY_DOMAIN${NC}"
        echo "  Директория: ${GREEN}$INSTALL_DIR${NC}"
        echo
        
        read -r -p "Продолжить с генерацией сертификатов? (y/n) " -n 1 response
        echo
        if [[ ! $response =~ ^[Yy]$ ]]; then
            print_success "Отменено"
            exit 0
        fi
    fi
    
    # Создание директорий
    print_step "Создание директорий..."
    mkdir -p letsencrypt cert
    print_success "Директории готовы"
    echo
    
    # Сборка и запуск
    run_command "Сборка Docker образов" "docker compose build -q"
    run_command "Генерация сертификатов" "docker compose run --rm certbot-generate"
    echo
    
    # Настройка cron для обновления
    setup_cron
    
    # Проверка результата
    if [ -d "cert/$PRIMARY_DOMAIN" ]; then
        print_header "Генерация сертификатов завершена!"
        echo "Директория: ${YELLOW}$INSTALL_DIR${NC}"
        echo "Сертификаты: ${YELLOW}$INSTALL_DIR/cert/$PRIMARY_DOMAIN/${NC}"
        echo "  • chain.crt - Цепь сертификата"
        echo "  • privkey.key - Приватный ключ"
        echo "  • certificate.yml - Конфигурация Traefik"
        echo
        print_success "Проект готов к использованию!"
    else
        print_error "Генерация сертификатов не удалась"
        exit 1
    fi
}

# Запуск main
main

