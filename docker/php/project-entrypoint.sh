#!/bin/sh
set -eu

# Only runtime data is writable by PHP; never change source, vendor or JWT keys.
runtime_dir=/var/www/html/var
mkdir -p "$runtime_dir/cache" "$runtime_dir/log" "$runtime_dir/sessions" "$runtime_dir/uploads"
if [ "$(id -u)" = 0 ]; then
    chown -R www-data:www-data "$runtime_dir"
fi
chmod -R u+rwX,g+rwX "$runtime_dir"
find "$runtime_dir" -type d -exec chmod g+s {} +

if [ "${1:-}" = --prepare-only ]; then
    exit 0
fi
umask 0002
exec docker-php-entrypoint "$@"
