-- Создаём базы UTF-8
CREATE DATABASE symfony_dev
    ENCODING 'UTF8'
    LC_COLLATE 'C.UTF-8'
    LC_CTYPE 'C.UTF-8'
    TEMPLATE template0;

CREATE DATABASE symfony_test
    ENCODING 'UTF8'
    LC_COLLATE 'C.UTF-8'
    LC_CTYPE 'C.UTF-8'
    TEMPLATE template0;

CREATE DATABASE symfony_prod
    ENCODING 'UTF8'
    LC_COLLATE 'C.UTF-8'
    LC_CTYPE 'C.UTF-8'
    TEMPLATE template0;

-- Права
GRANT ALL PRIVILEGES ON DATABASE symfony_dev TO symfony;
GRANT ALL PRIVILEGES ON DATABASE symfony_test TO symfony;
GRANT ALL PRIVILEGES ON DATABASE symfony_prod TO symfony;

-- Схемы
\connect symfony_dev;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS verification;
CREATE SCHEMA IF NOT EXISTS email;
CREATE SCHEMA IF NOT EXISTS dictionaries;
CREATE SCHEMA IF NOT EXISTS catalog;
GRANT ALL ON SCHEMA auth TO symfony;
GRANT ALL ON SCHEMA verification TO symfony;
GRANT ALL ON SCHEMA email TO symfony;
GRANT ALL ON SCHEMA dictionaries TO symfony;
GRANT ALL ON SCHEMA catalog TO symfony;

\connect symfony_test;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS verification;
CREATE SCHEMA IF NOT EXISTS email;
GRANT ALL ON SCHEMA auth TO symfony;
GRANT ALL ON SCHEMA verification TO symfony;
GRANT ALL ON SCHEMA email TO symfony;

\connect symfony_prod;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS verification;
CREATE SCHEMA IF NOT EXISTS email;
GRANT ALL ON SCHEMA auth TO symfony;
GRANT ALL ON SCHEMA verification TO symfony;
GRANT ALL ON SCHEMA email TO symfony;
