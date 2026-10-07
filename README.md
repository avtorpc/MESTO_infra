# ONMI Backend — Docker Orchestration

## Содержание

- [Структура проекта](#-структура-проекта)
- [Последовательность сборки](#-последовательность-сборки)


##  Структура проекта для локальной тестовой сборки
```
.
├── java_services
│   ├── event-api-service ( master )
│   ├── event-worker-service ( master )
├── services
│   ├── auth-service ( test )
│   ├── dictionaries-service ( test )
│   ├── email-service ( test )
│   └── verification-service ( test )
└──  ONMI_infra ( dev/local-stable )
    ├── Makefile
    ├── README.md
    ├── compose
    │   ├── 00-networks.yml
    │   ├── 10-infra.yml
    │   ├── 20-php-auth.yml
    │   ├── 21-php-verification.yml
    │   ├── 22-php-email.yml
    │   ├── 24-php-dictionaries.yml
    │   ├── 30-java-services.yml
    │   └── 40-nginx.yml
    ├── config
    │   └── routing.yml
    ├── docker
    │   ├── nginx
    │   │   └── default.conf
    │   ├── php
    │   │   ├── Dockerfile
    │   │   └── php.ini
    │   └── postgres
    │       └── init
    │           └── 01-init-databases.sql
    ├── docker-compose.yml
    ├── storage
    │   └── postgresql
    └── .env
```

##  Последовательность сборки
**Клонируем репозиторий и собираем оркестрацию Docker для проекта ONMI Backend на локальной машине:**

```bash
# Создаем структуру папок как указано выше. 
# В директории 
# java_services
# services
# клонируем неоходимые ветки с кодом.
```

```bash
# Клонируем основной репозиторий в ONMI_infra директорию
git clone -b main https://git.tknovosib.ru/omni/mp-infra.git .
```

```bash
# Удаляем все .gitkeep из папки storage/postgresql
# На macOS удаляем скрытые файлы .DS_Store
find . -name ".DS_Store" -delete
```

```bash
# Останавливаем старые контейнеры и удаляем тома
docker compose down -v
```

```bash
# Сборка и запуск контейнеров в фоне без миграций php контейнеров в Postgresql
make up
```

```bash
# Сборка и запуск контейнеров в фоне с миграций php контейнеров в Postgresql
make bootstrap
```

```bash
# Сборка и запуск контейнеров в фоне с миграций php контейнеров в Postgresql
make migrate 
```

```bash
# для очистки каталога PostgreSQL
make clean-db
```

```bash
# для полного пересоздания БД с повторным выполнением docker/postgres/init/01-init-databases.sql и последующим запуском миграций.
make rebuild-db
```

```bash
# Проверка состояния контейнеров
docker compose ps
```

**Важные рекомендации по наименованию корневой папки:**

- Не использовать длинные имена
- Не использовать двойные или тройные подчёркивания
- Не использовать пробелы

Пример корректного имени папки: `onmi_test_docker`

**Примечания:**

- Папка `storage/postgres/data` должны быть пустой при первом клоне
- Любые локальные файлы, созданные контейнерами, не должны попадать в Git
- Для сохранения структуры Git рекомендуется использовать `.gitkeeper` файлы в родительских директориях


**На случай злого кеша:**

```bash
# Смотрим какие есть контейнера
docker compose ps
```
```bash
# Если контейнера есть - удаляем их
docker rm -f $(docker ps -aq)
```
```bash
# Чистим все
docker compose down --volumes --remove-orphans
docker volume prune
```




## Веб-приложение «Место»

`make web-up` запускает только Symfony/Twig и Nginx на http://localhost:8080. `make web-down` останавливает эту сборку. Для другого порта: `WEB_PORT=8081 make web-up`. Полная сборка `make up` теперь использует web-service вместо Next.js и порт NGINX_PORT. Код Next.js сохранён, но не включён в основной запуск.
