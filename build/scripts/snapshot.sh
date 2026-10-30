#!/usr/bin/env sh
# rsnapshot backup_script: dumps PostgreSQL databases into the current directory, which rsnapshot
# sets to <snapshot_root>/tmp and afterwards copies into .sync/postgres/.
#
# Every dump is written uncompressed to the container's /tmp first, and compressed only after
# pg_dump has exited. pg_dump is never piped straight into gzip: that keeps the database snapshot
# and its locks open for as long as compression takes.
set -e
umask 077

SNAPSHOTS_FAILED=0
NL='
'

export PGPASSWORD="${DB_USER_PASSWORD}"
export PGSSLMODE="${DB_SSLMODE:-prefer}"
export PGCONNECT_TIMEOUT="${DB_CONNECT_TIMEOUT:-30}"
export PGAPPNAME="postgres-snapshot"
MAINTENANCE_DB="${DB_MAINTENANCE_DATABASE:-postgres}"

TMP_SQL="/tmp/postgres-snapshot.sql"
TMP_ERR="/tmp/postgres-snapshot.err"

# The newest client installed under /usr/libexec/postgresqlNN.
newest_client_major() {
  ls -d /usr/libexec/postgresql[0-9]* 2>/dev/null | sed 's|.*/postgresql||' | sort -n | tail -1
}

NEWEST_MAJOR=$(newest_client_major)
if [ -z "$NEWEST_MAJOR" ]; then
  echo "❌ ERROR: no PostgreSQL client found under /usr/libexec/postgresqlNN" >&2
  exit 1
fi
PSQL="/usr/libexec/postgresql${NEWEST_MAJOR}/psql"

# A libpq conninfo string naming one database. Passing a bare name would let a name containing
# '=' be parsed as a connection string.
conninfo_db() {
  printf "dbname='%s'" "$(printf '%s' "$1" | sed "s/[\\\\']/\\\\&/g")"
}

# Run one query and print unaligned, tuples-only output.
query() {
  database="$1"
  sql="$2"
  "$PSQL" -X -w -q -A -t -v ON_ERROR_STOP=1 \
    -h "${DB_HOSTNAME}" -p "${DB_PORT}" -U "${DB_USER_NAME}" \
    -d "$(conninfo_db "$database")" -c "$sql"
}

# Quote a value as an SQL string literal.
sql_literal() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

# Escape a value for a JSON string.
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r\t'
}

# e.g. "my-db" -> "MY_DB", "my.db" -> "MY_DB". Anything else outside [A-Z0-9_] also becomes "_",
# because the result is used as a variable name in eval.
normalize_db_name() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9_' '_'
}

# Choose pg_dump/pg_dumpall matching the server's major version, falling back to the newest client.
# A newer pg_dump can dump an older server; a dump is restored most faithfully by the same major.
select_client() {
  SERVER_VERSION_NUM=$(query "$MAINTENANCE_DB" "SHOW server_version_num;")
  SERVER_MAJOR=$((SERVER_VERSION_NUM / 10000))
  if [ -x "/usr/libexec/postgresql${SERVER_MAJOR}/pg_dump" ]; then
    CLIENT_MAJOR="$SERVER_MAJOR"
  else
    CLIENT_MAJOR="$NEWEST_MAJOR"
    echo "⚠️  Warning: no PostgreSQL ${SERVER_MAJOR} client installed; using ${NEWEST_MAJOR}." >&2
  fi
  PG_DUMP="/usr/libexec/postgresql${CLIENT_MAJOR}/pg_dump"
  PG_DUMPALL="/usr/libexec/postgresql${CLIENT_MAJOR}/pg_dumpall"
  echo "Server major ${SERVER_MAJOR}; using client $("$PG_DUMP" --version)"
}

# Print the databases to snapshot, one per line.
get_database_list() {
  if [ -n "${DB_DATABASES}" ]; then
    printf '%s\n' "${DB_DATABASES}" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$'
    return 0
  fi

  if [ "${DB_SNAPSHOT_ALL_DATABASES}" = "true" ] || [ "${DB_SNAPSHOT_ALL_DATABASES}" = "1" ]; then
    echo "Auto-discovering databases..." >&2
    DBS=$(query "$MAINTENANCE_DB" "SELECT datname FROM pg_database WHERE NOT datistemplate AND datallowconn ORDER BY datname;")
    if [ -n "${DB_EXCLUDE_DATABASES}" ]; then
      EXCLUDE_FILE=/tmp/postgres-snapshot.exclude
      printf '%s\n' "${DB_EXCLUDE_DATABASES}" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' > "$EXCLUDE_FILE" || true
      DBS=$(printf '%s\n' "$DBS" | grep -vxF -f "$EXCLUDE_FILE" || true)
      rm -f "$EXCLUDE_FILE"
    fi
    if [ -z "$DBS" ]; then
      echo "❌ ERROR: no databases found to snapshot" >&2
      return 1
    fi
    printf '%s\n' "$DBS"
    return 0
  fi

  echo "❌ ERROR: No database configuration provided" >&2
  echo "Please set one of: DB_DATABASES or DB_SNAPSHOT_ALL_DATABASES=true" >&2
  return 1
}

# Print "schema"."table" for every table in $1 whose name matches the LIKE pattern $2.
# Always double-quoted: pg_dump patterns fold unquoted text to lower case and treat several
# characters as regular expression syntax.
resolve_tables() {
  query "$1" "SELECT format('\"%s\".\"%s\"', replace(schemaname, '\"', '\"\"'), replace(tablename, '\"', '\"\"'))
    FROM pg_tables
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
      AND tablename LIKE $(sql_literal "$2")
    ORDER BY 1;" 2>/dev/null || true
}

# Print the stderr of the last failed command and clean up the staged files.
report_failure() {
  echo "Error output:"
  tail -200 "$TMP_ERR" 2>/dev/null || echo "(no error output captured)"
  rm -f "$TMP_SQL" "$TMP_SQL.gz" "$TMP_ERR"
}

# Compress the staged dump and move it to ./$1. Callers run this inside `if !`, where `set -e`
# does not apply, so every step checks its own result.
publish_dump() {
  if ! gzip -"${GZIP_COMPRESSION_LEVEL}" "$TMP_SQL" 2>> "$TMP_ERR"; then
    echo "❌ ERROR: Failed to compress the dump for $1"
    report_failure
    return 1
  fi
  if ! mv "$TMP_SQL.gz" "./$1" 2>> "$TMP_ERR"; then
    echo "❌ ERROR: Failed to move the dump into place as $1"
    report_failure
    return 1
  fi
  if [ -s "$TMP_ERR" ]; then
    echo "pg_dump messages:"
    cat "$TMP_ERR"
  fi
  rm -f "$TMP_ERR"
}

snapshot_single_database() {
  DB_NAME="$1"
  echo "=================================================="
  echo "Snapshotting database: $DB_NAME"
  echo "=================================================="

  case "$DB_NAME" in
    */*|.*)
      echo "❌ ERROR: database name '$DB_NAME' cannot be used as a file name; skipped"
      return 1
      ;;
  esac

  # Per-database structure-only tables: DB_STRUCT_TABLES_<NORMALIZED_DB_NAME>, falling back to
  # the global DB_STRUCT_TABLES.
  STRUCTURE_ONLY_TABLES=""
  VAR_NAME="DB_STRUCT_TABLES_$(normalize_db_name "$DB_NAME")"
  eval "STRUCTURE_ONLY_TABLES=\${${VAR_NAME}:-}"
  if [ -z "$STRUCTURE_ONLY_TABLES" ]; then
    STRUCTURE_ONLY_TABLES="${DB_STRUCT_TABLES}"
  fi

  set --
  if [ -n "$STRUCTURE_ONLY_TABLES" ]; then
    echo "Resolving structure-only tables for $DB_NAME..."
    RESOLVED=""
    # A for loop splits its word list once, with the IFS in force when it starts.
    OLD_IFS="$IFS"
    IFS=','
    for pattern in $STRUCTURE_ONLY_TABLES; do
      pattern=$(printf '%s' "$pattern" | sed 's/^ *//; s/ *$//' | tr '*' '%')
      if [ -n "$pattern" ]; then
        TABLES=$(resolve_tables "$DB_NAME" "$pattern")
        if [ -n "$TABLES" ]; then
          RESOLVED="${RESOLVED}${TABLES}${NL}"
        fi
      fi
    done
    IFS="$NL"
    for table in $RESOLVED; do
      set -- "$@" "--exclude-table-data=$table"
    done
    IFS="$OLD_IFS"
    if [ $# -gt 0 ]; then
      echo "✅ Structure-only tables for $DB_NAME: $(printf '%s' "$RESOLVED" | tr '\n' ' ')"
    else
      echo "No matching structure-only tables found for $DB_NAME"
    fi
  fi

  echo "Dumping database $DB_NAME..."
  if ! "$PG_DUMP" \
    -h "${DB_HOSTNAME}" -p "${DB_PORT}" -U "${DB_USER_NAME}" --no-password \
    --format=plain \
    --clean \
    --if-exists \
    --lock-wait-timeout="${DB_LOCK_WAIT_TIMEOUT}" \
    "$@" \
    --dbname="$(conninfo_db "$DB_NAME")" > "$TMP_SQL" 2> "$TMP_ERR"; then
    echo "❌ ERROR: Failed to dump database: $DB_NAME"
    report_failure
    return 1
  fi

  echo "Compressing the dump of $DB_NAME..."
  publish_dump "${DB_NAME}.gz" || return 1
  echo "✅ Snapshot completed for $DB_NAME: ./${DB_NAME}.gz"
  return 0
}

# All databases in one file, with roles, CREATE DATABASE and \connect, from pg_dumpall.
snapshot_combined() {
  echo "=================================================="
  echo "Creating combined snapshot: ALL_DATABASES.gz"
  echo "=================================================="
  set --
  if [ -n "${DB_EXCLUDE_DATABASES}" ]; then
    OLD_IFS="$IFS"
    IFS=','
    for name in ${DB_EXCLUDE_DATABASES}; do
      name=$(printf '%s' "$name" | sed 's/^ *//; s/ *$//')
      if [ -n "$name" ]; then
        set -- "$@" "--exclude-database=\"$(printf '%s' "$name" | sed 's/"/""/g')\""
      fi
    done
    IFS="$OLD_IFS"
  fi
  if ! "$PG_DUMPALL" \
    -h "${DB_HOSTNAME}" -p "${DB_PORT}" -U "${DB_USER_NAME}" --no-password \
    -l "$(conninfo_db "$MAINTENANCE_DB")" \
    --clean \
    --if-exists \
    --lock-wait-timeout="${DB_LOCK_WAIT_TIMEOUT}" \
    "$@" > "$TMP_SQL" 2> "$TMP_ERR"; then
    echo "❌ ERROR: Failed to create the combined snapshot"
    report_failure
    return 1
  fi
  publish_dump "ALL_DATABASES.gz" || return 1
  echo "✅ Combined snapshot created: ./ALL_DATABASES.gz"
  return 0
}

# Roles, role memberships and tablespaces. Reads pg_authid, so the user must be a superuser.
snapshot_globals() {
  echo "=================================================="
  echo "Snapshotting globals (roles and tablespaces)"
  echo "=================================================="
  if ! "$PG_DUMPALL" \
    -h "${DB_HOSTNAME}" -p "${DB_PORT}" -U "${DB_USER_NAME}" --no-password \
    -l "$(conninfo_db "$MAINTENANCE_DB")" \
    --globals-only > "$TMP_SQL" 2> "$TMP_ERR"; then
    echo "❌ ERROR: Failed to dump globals"
    report_failure
    echo "Dumping globals requires a superuser. Set DB_SNAPSHOT_GLOBALS=false otherwise."
    return 1
  fi
  publish_dump "globals.sql.gz" || return 1
  echo "✅ Globals snapshot completed: ./globals.sql.gz"
  return 0
}

generate_metadata_json() {
  START_TIME=$1
  END_TIME=$2
  DURATION=$3
  SERVER_VERSION=$(query "$MAINTENANCE_DB" "SELECT version();" 2>/dev/null || echo "unknown")
  SERVER_VERSION_SHORT=$(query "$MAINTENANCE_DB" "SHOW server_version;" 2>/dev/null || echo "unknown")

  cat > ./snapshot-metadata.json <<EOF
{
  "snapshot_info": {
    "start_time": "$START_TIME",
    "end_time": "$END_TIME",
    "duration_seconds": $DURATION,
    "frequency": "$(json_escape "${SNAPSHOT_FREQUENCY:-unknown}")"
  },
  "database_server": {
    "type": "PostgreSQL",
    "version": "$(json_escape "$SERVER_VERSION_SHORT")",
    "version_string": "$(json_escape "$SERVER_VERSION")"
  },
  "client_info": {
    "pg_dump_path": "$(json_escape "$PG_DUMP")",
    "pg_dump_version": "$(json_escape "$("$PG_DUMP" --version)")"
  },
  "configuration": {
    "DB_HOSTNAME": "$(json_escape "${DB_HOSTNAME:-}")",
    "DB_PORT": "$(json_escape "${DB_PORT:-}")",
    "DB_DATABASES": "$(json_escape "${DB_DATABASES:-}")",
    "DB_SNAPSHOT_ALL_DATABASES": "$(json_escape "${DB_SNAPSHOT_ALL_DATABASES:-}")",
    "DB_SNAPSHOT_COMBINED": "$(json_escape "${DB_SNAPSHOT_COMBINED:-}")",
    "DB_SNAPSHOT_GLOBALS": "$(json_escape "${DB_SNAPSHOT_GLOBALS:-}")",
    "DB_EXCLUDE_DATABASES": "$(json_escape "${DB_EXCLUDE_DATABASES:-}")",
    "DB_STRUCT_TABLES": "$(json_escape "${DB_STRUCT_TABLES:-}")",
    "DB_SSLMODE": "$(json_escape "${DB_SSLMODE:-}")",
    "DB_LOCK_WAIT_TIMEOUT": "$(json_escape "${DB_LOCK_WAIT_TIMEOUT:-}")",
    "RSNAPSHOT_RETAIN_HOURLY": "$(json_escape "${RSNAPSHOT_RETAIN_HOURLY:-}")",
    "RSNAPSHOT_RETAIN_DAILY": "$(json_escape "${RSNAPSHOT_RETAIN_DAILY:-}")",
    "RSNAPSHOT_RETAIN_WEEKLY": "$(json_escape "${RSNAPSHOT_RETAIN_WEEKLY:-}")",
    "RSNAPSHOT_RETAIN_MONTHLY": "$(json_escape "${RSNAPSHOT_RETAIN_MONTHLY:-}")",
    "GZIP_COMPRESSION_LEVEL": "$(json_escape "${GZIP_COMPRESSION_LEVEL:-}")"
  }
}
EOF
}

# Main execution
echo "=================================================="
echo "PostgreSQL Snapshot Script"
echo "=================================================="

SNAPSHOT_START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SNAPSHOT_START_EPOCH=$(date +%s)

select_client

DATABASE_LIST=$(get_database_list)
DATABASE_COUNT=$(printf '%s\n' "$DATABASE_LIST" | grep -c .)

echo "Databases to snapshot: $DATABASE_COUNT"
printf '%s\n' "$DATABASE_LIST" | sed 's/^/  - /'
echo ""

OLD_IFS="$IFS"
IFS="$NL"
for DB in $DATABASE_LIST; do
  IFS="$OLD_IFS"
  if ! snapshot_single_database "$DB"; then
    echo "❌ Failed to snapshot database: $DB"
    SNAPSHOTS_FAILED=1
  fi
  echo ""
done
IFS="$OLD_IFS"

if [ "${DB_SNAPSHOT_COMBINED}" = "true" ] || [ "${DB_SNAPSHOT_COMBINED}" = "1" ]; then
  if [ "${DB_SNAPSHOT_ALL_DATABASES}" = "true" ] || [ "${DB_SNAPSHOT_ALL_DATABASES}" = "1" ]; then
    if ! snapshot_combined; then
      SNAPSHOTS_FAILED=1
    fi
  else
    echo "⚠️  Warning: DB_SNAPSHOT_COMBINED requires DB_SNAPSHOT_ALL_DATABASES=true. Skipping combined snapshot."
  fi
  echo ""
fi

if [ "${DB_SNAPSHOT_GLOBALS}" = "true" ] || [ "${DB_SNAPSHOT_GLOBALS}" = "1" ]; then
  if ! snapshot_globals; then
    SNAPSHOTS_FAILED=1
  fi
  echo ""
fi

echo "=================================================="
echo "Generating snapshot metadata"
echo "=================================================="
SNAPSHOT_END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SNAPSHOT_END_EPOCH=$(date +%s)
generate_metadata_json "$SNAPSHOT_START_TIME" "$SNAPSHOT_END_TIME" "$((SNAPSHOT_END_EPOCH - SNAPSHOT_START_EPOCH))"
echo "✅ Metadata file created: ./snapshot-metadata.json"
echo ""

echo "=================================================="
if [ $SNAPSHOTS_FAILED -eq 0 ]; then
  echo "✅ All database snapshots completed successfully!"
  echo "=================================================="
  exit 0
else
  echo "⚠️  Some database snapshots failed. Please check the log above."
  echo "=================================================="
  exit 1
fi
