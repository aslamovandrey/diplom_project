#!/bin/bash
# init-script.sh - Выполняется после инициализации кластера PostgreSQL
# Patroni передает connection string как первый аргумент

CONN_STRING="$1"
LOG_FILE="/var/log/postgres_init.log"

echo "$(date): Starting initialization script" >> $LOG_FILE

# Функция для выполнения SQL
run_sql() {
    psql "$CONN_STRING" -c "$1" >> $LOG_FILE 2>&1
}

# Пример 1: Создание базы данных для приложения
run_sql "CREATE DATABASE appdb OWNER admin;"

# Пример 2: Создание схемы и таблиц
run_sql "CREATE SCHEMA IF NOT EXISTS app_schema;"

run_sql "CREATE TABLE IF NOT EXISTS app_schema.users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

# Пример 3: Установка расширений PostgreSQL
run_sql "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
run_sql "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

# Пример 4: Настройка прав доступа
run_sql "GRANT CONNECT ON DATABASE appdb TO admin;"
run_sql "GRANT ALL PRIVILEGES ON SCHEMA app_schema TO admin;"
run_sql "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app_schema TO admin;"

# Пример 5: Импорт начальных данных (если есть дамп)
# psql "$CONN_STRING" -d appdb -f /path/to/initial_data.sql >> $LOG_FILE 2>&1

echo "$(date): Initialization script completed" >> $LOG_FILE