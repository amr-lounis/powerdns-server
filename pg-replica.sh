#!/bin/sh
set -e

PGDATA="/var/lib/postgresql/data"

echo "PRIMARY_HOST:$PRIMARY_HOST"
echo "REPLICA_USER:$REPLICA_USER"

# pg_basebackup and postgres must not run as root
mkdir -p "$PGDATA"
chown postgres:postgres "$PGDATA"
chmod 0700 "$PGDATA"

do_basebackup() {
    # Clean any partial content left by a previous failed attempt
    find "$PGDATA" -mindepth 1 -delete

    attempt=0
    until su-exec postgres pg_basebackup \
            --pgdata="$PGDATA" -R \
            --slot=replication_slot \
            --host="$PRIMARY_HOST" --port=5432
    do
        attempt=$((attempt+1))
        echo "pg_basebackup failed (attempt $attempt). Retrying in 2s..."
        if [ "$attempt" -ge 30 ]; then
            echo "Giving up. Check PRIMARY_HOST, REPLICA_USER/PASSWORD and replication_slot."
            exit 1
        fi
        find "$PGDATA" -mindepth 1 -delete
        sleep 2
    done
    echo "Backup done."
}

if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "No valid data found, taking base backup..."
    do_basebackup
elif [ ! -f "$PGDATA/standby.signal" ]; then
    echo "Data exists but is not a standby (no standby.signal), rebuilding..."
    do_basebackup
else
    echo "Existing standby data found, refreshing connection settings..."
    # Refresh primary connection info in case HOST or password changed
    su-exec postgres sh -c "
        sed -i '/^primary_conninfo/d;/^primary_slot_name/d' '$PGDATA/postgresql.auto.conf'
        cat >> '$PGDATA/postgresql.auto.conf' <<EOF
primary_conninfo = 'host=$PRIMARY_HOST port=5432 user=$REPLICA_USER password=$REPLICA_PASSWORD'
primary_slot_name = 'replication_slot'
EOF
    "
fi

echo "Starting PostgreSQL..."
exec su-exec postgres postgres