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

`make web-up` — синоним `make registration-up`: запускает локальное окружение с единым `gateway_nginx`. `make web-down` — синоним `make registration-down`. Сайт доступен на http://localhost:8080; другой порт задаётся через `NGINX_PORT=8081 make web-up`. `make web-logs` показывает журналы web-service и общего Nginx. Полная сборка `make up` использует тот же gateway_nginx и конфигурацию docker/nginx/default.conf. Код Next.js сохранён, но не включён в основной запуск.

## Регистрация Место

`make registration-up` запускает сайт http://localhost:8080 вместе с auth, verification, dictionaries, Kafka и email. Письма локального режима доступны в Mailpit http://localhost:8025. Используется отдельный именованный том PostgreSQL, старые данные не очищаются. Остановка: `make registration-down`. Нужны непустые WEB_SERVICE_INTERNAL_TOKEN и REGISTRATION_INTERNAL_TOKEN из локального .env. Детали: [registration-mvp.md](../docs/flows/registration-mvp.md).

В каждом режиме работает один контейнер Nginx — `gateway_nginx` (Compose-сервис `nginx`). Он отдаёт статику web-service, направляет страницы в Symfony/PHP-FPM и проксирует `/auth/`, `/api/registration/`, `/email/`, `/api/refbook/`, `/catalog/`, `/event/`. Catalog доступен в полной сборке; окружение регистрации его не запускает. Все маршруты описаны в `docker/nginx/default.conf`, контейнер — в `compose/40-nginx.yml`. Локальная надстройка `compose/registration-local.yml` ограничивает порт Nginx адресом 127.0.0.1 и добавляет Mailpit и отдельный том базы. Отдельного web-nginx больше нет.

Основную сборку и локальное окружение регистрации следует запускать по очереди: они используют одни и те же имена контейнеров. Не используйте `down -v`, если требуется сохранить базу.


## Личные кабинеты — 8 октября 2026

Локальный стек make registration-up / make web-up включает catalog-service; make registration-migrate применяет его миграции. web передаёт запросы профилей через CATALOG_SERVICE_URL=http://nginx/catalog, catalog получает исходные регистрационные поля через AUTH_SERVICE_URL=http://nginx/auth и справочники через DICTIONARY_SERVICE_URL. Веб-переход после входа: /cabinet; /user.html и /employer.html — адреса совместимости. Для новых изменений кода очищайте prod-кеш Symfony до ручной проверки новых маршрутов. Подробнее: ../docs/flows/cabinet-and-assessment-selection.md.
