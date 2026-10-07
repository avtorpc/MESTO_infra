FROM php:8.4-fpm

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

RUN pecl install rdkafka \
    && docker-php-ext-enable rdkafka

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Копируем php.ini для dev настроек
COPY php.ini /usr/local/etc/php/conf.d/99-custom.ini

WORKDIR /var/www

# Без entrypoint, просто запускаем php-fpm
CMD ["php-fpm"]
