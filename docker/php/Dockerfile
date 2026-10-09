FROM php:8.4-fpm AS php-base

ARG APP_ENV=dev
ARG APP_DEBUG=1

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libpq-dev \
    librdkafka-dev \
    libzip-dev \
    zip \
    curl

RUN docker-php-ext-install \
    pdo \
    pdo_pgsql \
    zip \
    pcntl

RUN pecl install redis \
    && docker-php-ext-enable redis

RUN pecl channel-update pecl.php.net \
    && pecl install -f rdkafka-6.0.5 \
    && docker-php-ext-enable rdkafka

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Копируем php.ini для dev настроек
COPY php.ini /usr/local/etc/php/conf.d/99-custom.ini

WORKDIR /var/www

# Без entrypoint, просто запускаем php-fpm
CMD ["php-fpm"]

# Project catalog only. Download and keep CAs inside the image, outside all host mounts.
# Do not update the container system CA store: only GigaChatClient uses this bundle.
FROM php-base AS catalog-gigachat
RUN mkdir -p /opt/gigachat \
    && curl --fail --silent --show-error --proto '=https' --tlsv1.2 \
       https://gu-st.ru/content/lending/russian_trusted_root_ca_pem.crt \
       -o /opt/gigachat/root.crt \
    && curl --fail --silent --show-error --proto '=https' --tlsv1.2 \
       https://gu-st.ru/content/lending/russian_trusted_sub_ca_pem.crt \
       -o /opt/gigachat/sub.crt \
    && openssl x509 -in /opt/gigachat/root.crt -noout -checkend 2592000 \
    && openssl verify -CAfile /opt/gigachat/root.crt /opt/gigachat/sub.crt \
    && awk 'FNR == 1 { print "" } { print }' /etc/ssl/certs/ca-certificates.crt /opt/gigachat/root.crt /opt/gigachat/sub.crt > /opt/gigachat/ca-bundle.pem \
    && openssl crl2pkcs7 -nocrl -certfile /opt/gigachat/ca-bundle.pem | openssl pkcs7 -print_certs -noout > /dev/null \
    && chmod 444 /opt/gigachat/*.crt /opt/gigachat/ca-bundle.pem \
    && chmod 555 /opt/gigachat

# All other services retain the existing image and standard certificate trust.
FROM php-base AS default
