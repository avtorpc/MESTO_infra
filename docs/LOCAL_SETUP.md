# Установка и локальный запуск «Место»

Актуально на 9 октября 2026. Все команды запускаются в обычном терминале macOS/Linux; на Windows — в терминале WSL 2 с Linux-контейнерами Docker Desktop. Имя корневой папки можно выбрать любое; имена вложенных папок нужно сохранить.

## 1. Что установить на компьютер

- Git и доступ к девяти репозиториям проекта. Для закрытых репозиториев сначала примите приглашения владельца. Используйте собственные учётные данные GitHub.
- [Docker Desktop](https://docs.docker.com/desktop/) на macOS/Windows либо Docker Engine с [плагином Compose](https://docs.docker.com/compose/install/) на Linux. Docker должен быть запущен перед выполнением команд.
- Docker Compose **2.24.4 или новее**: локальная конфигурация использует `!override`. [Описание требования Docker](https://docs.docker.com/reference/compose-file/merge/#replace-value).
- `make` и OpenSSL. На macOS командные инструменты можно установить через `xcode-select --install`; на Ubuntu/WSL — `sudo apt-get update`, затем `sudo apt-get install git make openssl`.
- Интернет для загрузки Docker-образов, Composer/Maven-зависимостей и официальных сертификатов внутри образа каталога. Для генерации и оценки заданий нужен доступ к GigaChat API.

Проверьте установку:

```bash
git --version
docker info
docker compose version
make --version
openssl version
```

PHP, Composer, Java, Maven и Nginx отдельно на компьютер устанавливать не требуется: они используются внутри контейнеров. Frontend Next.js в текущем локальном запуске не участвует.

## 2. Структура и клонирование

```text
MESTO/
├── ONMI_infra/                    # Репозиторий MESTO_infra
│   ├── README.md
│   ├── docs/LOCAL_SETUP.md         # Эта инструкция
│   ├── Makefile
│   ├── .env.template              # Шаблон без реальных ключей
│   ├── .env                       # Создаётся локально, не хранится в Git
│   ├── compose/                   # Конфигурации контейнеров
│   ├── docker/                    # Dockerfile, Nginx, первичная настройка БД
│   └── config/
│       ├── routing.yml            # Маршруты событий Kafka
│       └── jwt/                   # JWT-ключи, создаются локально
├── services/
│   ├── auth-service/
│   ├── verification-service/
│   ├── email-service/
│   ├── dictionaries-service/
│   ├── catalog-service/
│   └── web-service/
└── java_services/
    ├── event-api-service/
    └── event-worker-service/
```

У каждого из девяти каталогов свой Git-репозиторий. Общий Git в `MESTO` для запуска не нужен. Дополнительная папка `docs` в корне старой рабочей копии не требуется для выполнения этой инструкции.

В новой пустой папке выполните:

```bash
mkdir -p MESTO/services MESTO/java_services
cd MESTO
git clone https://github.com/avtorpc/MESTO_infra.git ONMI_infra
git clone https://github.com/avtorpc/auth-service.git services/auth-service
git clone https://github.com/avtorpc/verification-service.git services/verification-service
git clone https://github.com/avtorpc/email-service.git services/email-service
git clone https://github.com/avtorpc/dictionaries-service.git services/dictionaries-service
git clone https://github.com/avtorpc/catalog-service.git services/catalog-service
git clone https://github.com/avtorpc/web-service.git services/web-service
git clone https://github.com/avtorpc/event-api-service.git java_services/event-api-service
git clone https://github.com/avtorpc/event-worker-service.git java_services/event-worker-service
cd ONMI_infra
```

Репозиторий GitHub называется `MESTO_infra`, а локальная папка — **ONMI_infra**. Для нового участника все изменения должны быть предварительно отправлены владельцем в соответствующие репозитории. Клонирование не переносит несохранённые изменения, существующую базу, письма или личные настройки другого разработчика.

## 3. Подготовка окружения

Для первой установки, когда `.env` ещё отсутствует:

```bash
cp .env.template .env
chmod 600 .env
```

Откройте `.env` в редакторе. Создайте четыре независимых случайных значения командой `openssl rand -hex 32`, запуская её отдельно для каждого параметра, и заполните:

| Параметр | Что указать |
| --- | --- |
| `APP_SECRET` | Первое случайное значение |
| `POSTGRES_PASSWORD` | Второе случайное значение; hex не требует URL-экранирования |
| `WEB_SERVICE_INTERNAL_TOKEN` | Третье случайное значение, общий внутренний доступ web → сервисы |
| `REGISTRATION_INTERNAL_TOKEN` | Четвёртое случайное значение, внутренний доступ verification → auth |
| `GIGACHAT_AUTH_KEY` | Ваш ключ авторизации GigaChat, если нужна генерация/оценка заданий |

Ключ GigaChat — значение Authorization key в Base64, **без** префикса `Basic`. `GIGACHAT_SCOPE=GIGACHAT_API_PERS` соответствует ранее выбранному типу доступа проекта. Если используется другой тип аккаунта, scope должен соответствовать ему. Не заменяйте этот ключ токеном GitHub или OpenAI.

Без GigaChat-ключа сайт, регистрация и вход доступны; создание задания выдаёт сообщение о ненастроенном подключении. Для тестовой почты реальные SMTP/SMS-пароли не нужны.

Оставьте значения шаблона для локального запуска:

```dotenv
NGINX_PORT=8080
DEFAULT_URI=http://localhost:8080
POSTGRES_USER=symfony
POSTGRES_DB=symfony_dev
POSTGRES_PORT=5432
MAILER_DSN=smtp://mailpit:1025
MAIL_FROM_ADDRESS=noreply@example.invalid
GIGACHAT_MODEL=GigaChat-2-Max
JWT_PRIVATE_KEY_PATH=../config/jwt/private.pem
JWT_PUBLIC_KEY_PATH=../config/jwt/public.pem
JWT_CONTAINER_DIR=/var/jwt
```

Первичный SQL создаёт базы `symfony_dev`, `symfony_test`, `symfony_prod` и выдаёт права пользователю `symfony`. Не меняйте имя пользователя/локальной базы без согласованной правки первичного SQL. В режиме `registration-up` PostgreSQL использует отдельный именованный том; `POSTGRES_DATA_VOLUME` из базового шаблона заменяется локальной надстройкой.

Адреса `http://nginx`, `redis://redis:6379`, `kafka:9092` — внутренние имена контейнеров; не заменяйте их на `localhost`. JWT-пути в шаблоне отсчитываются от каталога первого Compose-файла (`ONMI_infra/compose`), поэтому `../config/jwt` указывает на `ONMI_infra/config/jwt`.

Не перезаписывайте имеющийся `.env` шаблоном при обновлении: это удалит ваши локальные настройки. Файлы `.env` и JWT-ключей исключены из Git.

## 4. JWT-ключи для входа

Каждая новая независимая установка создаёт собственную пару RSA-ключей. Это ключи подписи приложения, а не корневые сертификаты и не установка доверия в ОС.

Следующий блок создаёт пару только при отсутствии обоих файлов:

```bash
mkdir -p config/jwt
if [ -e config/jwt/private.pem ] || [ -e config/jwt/public.pem ]; then
  echo 'JWT-файлы уже существуют. Проверьте пару; не перезаписывайте её при обычном запуске.'
else
  (
    umask 077
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out config/jwt/private.pem &&
    openssl pkey -in config/jwt/private.pem -pubout -out config/jwt/public.pem &&
    chmod 644 config/jwt/public.pem
  )
fi
```

Приватный ключ остаётся с ограниченными правами. Если сохранился только один файл, восстановите согласованную пару перед запуском. Смена пары на существующей установке делает ранее выданные токены непригодными.

## 5. Первый запуск контейнеров

Все дальнейшие команды выполняются из `ONMI_infra`:

```bash
make registration-check
make registration-up
make registration-ps
```

`registration-check` проверяет синтаксис и объединение Compose-файлов без вывода секретов; он не проверяет подлинность API-ключа. `registration-up` последовательно:

1. Собирает образы и запускает контейнеры проекта `mesto-web`.
2. Ожидает готовности контейнеров с healthcheck.
3. Создаёт отсутствующие `.env` PHP-сервисов из их `.env.example` и устанавливает зависимости из `composer.lock`. Переменные контейнера имеют приоритет.
4. Применяет миграции auth, verification, email, dictionaries и catalog.
5. Проверяет и перезагружает конфигурацию общего Nginx.

При первой сборке загрузка зависимостей занимает время. Перед ручной проверкой дождитесь успешного завершения команды, а не только появления контейнеров в Docker Desktop. При превышении времени ожидания проверьте журналы и повторите запуск после устранения причины; базу удалять не нужно.

`make web-up` — синоним этой команды. Он тоже запускает весь стек, включая каталог, Kafka и Mailpit.

## 6. Какие контейнеры запускаются

| Compose-сервис | Роль |
| --- | --- |
| `nginx` | Единая точка входа; страницы и статика web-service, прокси к микросервисам |
| `web-service` | Symfony/Twig, формы, кабинеты и страницы заданий |
| `verification-service` | Регистрация, код подтверждения и ограничения |
| `auth-service` | Создание аккаунта, пароль, вход и токены |
| `email-service` | Обработка запросов отправки писем |
| `dictionaries-service` | Настройки и справочники |
| `catalog-service` | Профили, выбор тестирования, задания, ответы и оценки GigaChat |
| `event-api-service` | Приём событий для Kafka |
| `event-worker-service` | Доставка событий к внутренним обработчикам |
| `postgres` | Базы и схемы сервисов |
| `redis` | Кэш и ограничения |
| `kafka` | Передача событий, в том числе регистрационных писем |
| `mailpit` | Локальный приём и просмотр тестовых писем |

Образы Mailpit, Nginx, PostgreSQL, Redis и Kafka Docker скачивает автоматически. Отдельно клонировать их исходники не требуется. Код шести PHP-сервисов и двух Java-сервисов берётся из соседних папок, поэтому структура клонирования обязательна.

## 7. Проверка работы

Откройте:

- http://localhost:8080 — главная страница.
- http://localhost:8025 — Mailpit, письма с кодами.
- http://localhost:8080/cabinet — кабинет после входа.

Для проверки зарегистрируйте соискателя или работодателя, найдите письмо в Mailpit, подтвердите код и войдите с выбранным паролем. У соискателя сохраните выбор тестирования, получите задание, сохраните ответ и отправьте его на оценку. Для последнего шага нужен действующий ключ и доступная квота GigaChat.

Повторная регистрация занятого email отклоняется; для нового теста используйте другой адрес. Mailpit не пересылает тестовые письма в реальные внешние ящики.

Проверки контракта заданий, схемы БД и шаблонов без платных запросов к ИИ:

```bash
make assessment-test
```

Они используют отдельные временные базы и не сбрасывают рабочие регистрации. Эта команда не подтверждает доступность внешнего GigaChat или правильность его оценки конкретного решения.

## 8. Повторный запуск и обновление

| Действие | Команда из ONMI_infra |
| --- | --- |
| Запуск/пересборка, зависимости и миграции | `make registration-up` |
| Состояние локального стека | `make registration-ps` |
| Журналы всех контейнеров | `make registration-logs` |
| Журналы одного сервиса | `make registration-logs SERVICE=catalog-service` |
| Перезапуск существующих контейнеров | `make registration-restart` |
| Перезапуск одного сервиса | `make registration-restart SERVICE=email-service` |
| Повторное применение миграций | `make registration-migrate` |
| Очистка prod-кэша Symfony | `make registration-cache` |
| Остановка без удаления базы | `make registration-down` |

Для получения обновлений выполните `git pull` в каждом нужном репозитории отдельно. Если есть локальные изменения, сначала сохраните их и разрешите конфликты; не сбрасывайте их вслепую. После обновления выполните `make registration-up`, а при изменении маршрутов, сервисов или Twig-шаблонов — также `make registration-cache`.

После изменения `.env`, Compose или Dockerfile нужен `registration-up`: простой `restart` не применяет новую конфигурацию окружения и не пересобирает образ. После первого запуска, если возникла ошибка отсутствующего vendor, отдельно доступна команда `make registration-deps`.

Для другого порта отредактируйте `NGINX_PORT` и `DEFAULT_URI` в локальном `.env`, затем повторите запуск. Mailpit использует фиксированный порт 8025.

## 9. Хранение данных и правила остановки

PostgreSQL локального проекта хранит данные в томе `mesto-web_registration_data`. Регистрации, аккаунты, задания, ответы и оценки сохраняются после `make registration-down` и последующего запуска. Образы и тома не передаются через Git; новая установка начинает с собственной базой и собственными ключами.

Mailpit не имеет настроенного постоянного тома: при пересоздании контейнера старые письма могут исчезнуть. Это не удаляет аккаунты из PostgreSQL. Redis и Kafka также не имеют настроенных постоянных томов; их состояние не является резервной копией базы. Данные этих контейнеров могут теряться при пересоздании.

Не используйте для обычного обновления `down -v`, `docker volume prune`, `make clean-db`, `make rebuild-db` или `make rebuild-db-hard`. Эти команды могут удалить данные; последняя также затрагивает контейнеры вне проекта. Для локального сценария используйте только команды `registration-*`/`web-*` из этой инструкции. Старые `make ps`, `make logs`, `make up`, `make bootstrap` относятся к другому набору Compose-настроек.

Не запускайте одновременно старый и локальный стек: имена контейнеров фиксированы и будут конфликтовать. Файл `docker-compose.yml` не используется командой `registration-up`; простой `docker compose up` не эквивалентен запуску по этой инструкции.

## 10. GigaChat и сертификаты

Параметры GigaChat передаются только catalog-service. Сертификаты скачиваются **во время сборки внутри Docker target catalog-gigachat**, хранятся в `/opt/gigachat` вне bind mounts и используются только клиентом GigaChat через `cafile`. Системное хранилище доверия контейнера не изменяется. Образ `mesto-catalog-gigachat` отделён от общего PHP-образа.

**Запрещено устанавливать сертификаты российского происхождения в macOS/любую ОС хоста, Keychain, глобальные хранилища доверия и глобальные настройки TLS.** Не скачивайте эти сертификаты в каталоги хоста; не отключайте проверку HTTPS. Для этой инструкции ручная установка сертификатов на компьютер не нужна.

Реальные ключи и `.env` не добавляйте в Git. Не публикуйте полный вывод `docker compose config` или окружение контейнеров: они могут содержать секреты. Команда `registration-check` использует безопасный `config --quiet`.

## 11. Типичные проблемы

| Проблема | Что проверить |
| --- | --- |
| Docker daemon недоступен | Запустите Docker Desktop; проверьте `docker info` |
| Неизвестный YAML-тег `!override` | Обновите Compose до 2.24.4 или новее |
| GitHub 403 при клонировании | Принято ли приглашение и используются ли собственные учётные данные с доступом к репозиторию |
| Файл JWT отсутствует или стал каталогом | Ключи нужно создать до запуска bind mounts; проверьте пути в `.env` |
| Контейнер с таким именем уже существует | Остановите прежний стек его командой; не удаляйте все контейнеры компьютера |
| Порт занят | Освободите нужный порт; для сайта измените NGINX_PORT/DEFAULT_URI. Также используются 5432, 6379, 9092, 9093 и 8025 |
| База/схема отсутствует | Проверьте журнал postgres и успешное завершение миграций; первичный SQL выполняется только на новом томе |
| Не проходит пароль PostgreSQL | POSTGRES_PASSWORD должен совпадать с паролем уже созданного тома; изменение `.env` не меняет пароль внутри существующей БД |
| Vendor отсутствует | Выполните `make registration-deps`, затем `make registration-up` |
| После обновления остался старый экран | Выполните `make registration-cache`, обновите страницу |
| Генерация/оценка недоступна | Проверьте ключ, scope, квоту, доступ к сети и журнал catalog-service; не отключайте TLS |

На Linux/WSL приватный JWT-файл должен быть доступен PHP-процессу контейнера для чтения. Проверка после запуска:

```bash
docker exec -u www-data auth_service_php test -r /var/jwt/private.pem
```

Если доступ закрыт, настройте права под вашу конфигурацию Docker. Для обычного rootful Docker на Linux можно выдать только чтение UID 33 через ACL (`setfacl -m u:33:r config/jwt/private.pem`; пакет `acl`). Для rootless Docker сопоставление UID отличается. Не делайте приватный ключ общедоступным для решения этой проблемы.

Если сохраняется ошибка, передайте разработчику название сервиса и очищенное сообщение из журнала. Ключи, пароли и полный вывод окружения не отправляйте.
