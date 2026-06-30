# Генератор Wildcard SSL Сертификатов

Автоматическое получение и управление wildcard SSL сертификатами от Let`s Encrypt через Cloudflare DNS.

## 🚀 Установка

### Способ 1: Интерактивная установка (рекомендуется)

```bash
bash <(wget -qO- https://raw.githubusercontent.com/sansepro/wildcard/main/install.sh)
```

### Способ 2: Полностью автоматическая (без вопросов)

```bash
bash <(wget -qO- https://raw.githubusercontent.com/sansepro/wildcard/main/install.sh) \
  -e admin@example.com \
  -t your_cloudflare_token \
  -d "*.example.com,example.com" \
  -p example.com \
  -y
```

### Способ 3: Минимальный вывод (quiet mode)

```bash
bash <(wget -qO- https://raw.githubusercontent.com/sansepro/wildcard/main/install.sh) \
  -e admin@example.com \
  -t your_cloudflare_token \
  -d "*.example.com,example.com" \
  -p example.com \
  -y -q
```

## 📋 Требования

- Ubuntu/Debian Linux
- Домен на Cloudflare
- Cloudflare API Token с правами `Zone:Read` и `DNS:Edit`

Docker будет установлен автоматически.

## ⚙️ Флаги установщика

### Основные параметры

```
-e, --email EMAIL           Email для Let`s Encrypt
-t, --token TOKEN           Cloudflare API Token
-d, --domain DOMAIN         Домены (*.example.com,example.com)
-p, --primary DOMAIN        Основной домен (example.com)
```

### Дополнительные параметры

```
-i, --install-dir DIR       Директория установки (дефолт: /opt/certbot)
-y, --yes                   Ответить 'да' на все вопросы (автоматический режим)
-q, --quiet                 Минимальный вывод (только ошибки)
--skip-docker-check         Пропустить проверку Docker
--skip-cron                 Пропустить настройку cron
-h, --help                  Показать справку
```

## 🔑 Получение API токена

1. [dash.cloudflare.com](https://dash.cloudflare.com) → Профиль → API Tokens
2. Create Token → выберите "Edit zone DNS"
3. Установите права: Zone - DNS - Edit и Zone - Zone - Read
4. Скопируйте токен

## 📁 Сертификаты

После установки сертификаты будут в `/opt/certbot/cert/<домен>/`:

```
chain.crt       # Цепь сертификата
privkey.key     # Приватный ключ
certificate.yml # Конфиг для Traefik
```

## 📚 Использование

### Nginx

```nginx
server {
    listen 443 ssl;
    server_name example.com *.example.com;
    ssl_certificate /opt/certbot/cert/example.com/chain.crt;
    ssl_certificate_key /opt/certbot/cert/example.com/privkey.key;
}
```

### Traefik

```yaml
include:
  - /opt/certbot/cert/example.com/certificate.yml
```

### Apache

```apache
<VirtualHost *:443>
    ServerName example.com
    SSLEngine on
    SSLCertificateFile /opt/certbot/cert/example.com/chain.crt
    SSLCertificateKeyFile /opt/certbot/cert/example.com/privkey.key
</VirtualHost>
```

## 🔄 Обновление

### Вручную

```bash
cd /opt/certbot && docker compose run --rm certbot-renew
```

### Автоматически

Cron настраивается автоматически (если не указан флаг `--skip-cron`): `0 5 * * *` (05:00 каждый день)

Просмотр логов:
```bash
tail -f /tmp/certbot_cron.log
```

## 🆘 Проблемы

### Docker не найден
Установщик установит его автоматически. Или пропустите проверку флагом `--skip-docker-check`.

### Валидация challenge не удалась
- Проверьте домен подключен к Cloudflare
- Проверьте права API токена
- Дайте 60+ секунд на распространение DNS

### Логи Docker
```bash
cd /opt/certbot && docker compose logs
```

## 📄 Лицензия

MIT License
