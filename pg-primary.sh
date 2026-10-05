#!/bin/bash
set -e

# Load .env for manual runs. Inside the container vars already
# come from compose env_file, so skip if file is not present.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$SCRIPT_DIR/.env"
  set +a
fi

: "${DB1_USER:?DB1_USER missing in .env}"
: "${REPLICA_USER:?REPLICA_USER missing in .env}"
: "${REPLICA_PASSWORD:?REPLICA_PASSWORD missing in .env}"
: "${PGDATA:?PGDATA missing}"

echo "--------------------------------------------------"
echo "DB1_USER:$DB1_USER"
# echo "DB1_PASSWORD:$DB1_PASSWORD"
echo "REPLICA_USER:$REPLICA_USER"
# echo "REPLICA_PASSWORD:$REPLICA_PASSWORD"
echo "PRIMARY_HOST:$PRIMARY_HOST"
echo "--------------------------------------------------"

psql -v ON_ERROR_STOP=1 --username "$DB1_USER" --dbname "$DB1_USER" <<-EOSQL
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$REPLICA_USER') THEN
            CREATE USER "$REPLICA_USER" WITH REPLICATION ENCRYPTED PASSWORD '${REPLICA_PASSWORD//\'/\'\'}';
        ELSE
            ALTER USER "$REPLICA_USER" WITH REPLICATION ENCRYPTED PASSWORD '${REPLICA_PASSWORD//\'/\'\'}';
        END IF;
    END
    \$\$;
    SELECT * FROM pg_create_physical_replication_slot('replication_slot') WHERE NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'replication_slot');
EOSQL

# Allow the replica user to connect for streaming replication.
# This script runs during initdb, before Postgres does its final
# restart into the real server process, so this line is already
# active the moment the server starts accepting connections.
grep -qxF "host replication ${REPLICA_USER} 0.0.0.0/0 scram-sha-256" "$PGDATA/pg_hba.conf" || echo "host replication ${REPLICA_USER} 0.0.0.0/0 scram-sha-256" >> "$PGDATA/pg_hba.conf"