#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

: "${DB1_USER:?DB1_USER missing in $ENV_FILE}"
: "${DB1_PASSWORD:?DB1_PASSWORD missing in $ENV_FILE}"

DB_USER="${DB_USER:-$DB1_USER}"
DB_NAME="${DB_NAME:-$DB1_USER}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/database_backups}"

# Check if pg_restore exists
if ! command -v pg_restore &> /dev/null; then
    echo "Error: pg_restore is not installed."
    exit 1
fi

# Get backup files into array
mapfile -t FILES < <(ls -1t "$BACKUP_DIR"/*.backup 2>/dev/null)

if [ ${#FILES[@]} -eq 0 ]; then
    echo "Error: No .backup files found!"
    exit 1
fi

# Print numbered options
echo "Select a backup file to restore:"
for i in "${!FILES[@]}"; do
    echo "  $((i+1))) $(basename "${FILES[$i]}")"
done

# Read choice
read -p "Enter number [Default 1]: " CHOICE
CHOICE="${CHOICE:-1}"

# Get file path
SELECTED_FILE="${FILES[$((CHOICE-1))]}"

if [ -z "$SELECTED_FILE" ] || [ ! -f "$SELECTED_FILE" ]; then
    echo "Error: Invalid selection!"
    exit 1
fi

export PGPASSWORD="$DB1_PASSWORD"

echo "Restoring: $SELECTED_FILE"
pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" --clean -v "$SELECTED_FILE"

unset PGPASSWORD

echo "Done!"