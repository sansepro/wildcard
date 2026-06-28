# Wildcard

Автоматическая настройка и получение wildcard SSL-сертификатов через **Cloudflare DNS API** с использованием Let's Encrypt.

Проект предназначен для быстрого выпуска и автоматического продления сертификатов вида `*.example.com` и `example.com` без необходимости вручную создавать DNS-записи.

---

## Возможности

* 🔒 Получение wildcard SSL-сертификатов Let's Encrypt
* ☁️ Проверка домена через Cloudflare DNS API
* 🚀 Установка одной командой
* 📂 Хранение сертификатов в указанной директории
* 🐳 Поддержка Docker

---

# Установка

Склонируйте репозиторий:

```bash
git clone https://github.com/sansepro/wildcard.git && cd ./wildcard
```

Запустите установочный скрипт:

```bash
bash start.sh
```

---

# Настройка

Перед запуском изменить файл `.env`.

Пример:

```env
EMAIL="site@example.com"
CLOUDFLARE_API_TOKEN="your_cloudflare_api_token"

DOMAIN="*.example.com,example.com"
PRIMARY_DOMAIN="example.com"

BASE_CERT_PATH="/certificates"
```

## Описание переменных

| Переменная             | Описание                                                                             |
| ---------------------- | ------------------------------------------------------------------------------------ |
| `EMAIL`                | Email, используемый при регистрации сертификата Let's Encrypt.                       |
| `CLOUDFLARE_API_TOKEN` | API Token Cloudflare с правами на управление DNS-записями нужной зоны.               |
| `DOMAIN`               | Домены, для которых будет выпущен сертификат. Несколько доменов разделяются запятой. |
| `PRIMARY_DOMAIN`       | Основной домен, используемый в качестве имени сертификата.                           |
| `BASE_CERT_PATH`       | Директория, в которой будут храниться сертификаты и ключи.                           |

---

# Требования

* Docker
* Docker Compose
* Git
* Домен, подключенный к Cloudflare
* API Token Cloudflare с правами:

```
Zone
 ├── DNS:Edit
 └── Zone:Read
```

---

# Получаемый сертификат

При указанной конфигурации

```env
DOMAIN="*.example.com,example.com"
```

будет выпущен сертификат для:

* `example.com`
* `*.example.com`

---

# Обновление

Для обновления проекта выполните:

```bash
cd wildcard
git pull
bash start.sh
```

---

# Использование

После настройки `.env` достаточно выполнить:

```bash
bash start.sh
```

---

# Лицензия

MIT License.
