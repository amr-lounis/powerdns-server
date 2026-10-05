#!/bin/bash

#sudo apt update
#sudo apt install postgresql-client

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB1_USER:?DB1_USER missing in $ENV_FILE}"
DB_NAME="${DB1_USER:?DB1_USER missing in $ENV_FILE}"
: "${DB1_PASSWORD:?DB1_PASSWORD missing in $ENV_FILE}"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="$SCRIPT_DIR/database_backups"

export PGPASSWORD="$DB1_PASSWORD"

mkdir -p "$BACKUP_DIR"

pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/db-$TIMESTAMP.sql"
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -F c "$DB_NAME" > "$BACKUP_DIR/db-$TIMESTAMP.backup"

unset PGPASSWORD

echo "ok: $BACKUP_DIR"