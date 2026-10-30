#!/bin/bash
# Automated test runner for docker-postgres-snapshot.
# Runs every snapshot scenario against PostgreSQL 17 and 18, then restores the dumps into empty
# servers of the same major and checks the data.
set -e
cd "$(dirname "$0")"

FAILED=0
TESTS_PASSED=0
TESTS_TOTAL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Snapshot files are written by root with mode 0600, so the checks read a copy owned by the
# invoking user, refreshed after each run.
VIEW=./view

run_test() {
    local test_name="$1"
    local test_command="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -n "Test $TESTS_TOTAL: $test_name... "
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}"
        FAILED=1
    fi
}

refresh_view() {
    docker run --rm -v "$(pwd)/snapshots:/s:ro" -v "$(pwd):/w" alpine:3.24 \
        sh -c "rm -rf /w/view && mkdir -p /w/view && cp -a /s/. /w/view/ && chown -R $(id -u):$(id -g) /w/view"
}

# Run a snapshot service; extra arguments are the rsnapshot level.
snapshot() {
    docker compose run --rm "$@"
}

# psql against a compose service, reading SQL from stdin.
psql_in() {
    local service="$1"; shift
    docker compose exec -T "$service" psql -U postgres -X -q -v ON_ERROR_STOP=1 "$@"
}

query_in() {
    local service="$1" database="$2" sql="$3"
    docker compose exec -T "$service" psql -U postgres -X -q -A -t -d "$database" -c "$sql"
}

# The file exists, is valid gzip, and is a complete pg_dump plain-format dump.
validate_dump() {
    local file="$1"
    [ -f "$file" ] || return 1
    gunzip -t "$file" || return 1
    gunzip -c "$file" | grep -q "PostgreSQL database dump complete"
}

# The table's DDL is in the dump and its data is not.
validate_structure_only() {
    local file="$1" table="$2"
    gunzip -c "$file" | grep -qF "CREATE TABLE ${table} (" || return 1
    ! gunzip -c "$file" | grep -qF "COPY ${table} "
}

# The table's data is in the dump.
validate_has_data() {
    local file="$1" table="$2"
    gunzip -c "$file" | grep -qF "COPY ${table} "
}

validate_metadata() {
    local file="$1" client_major="$2"
    [ -f "$file" ] || return 1
    python3 -m json.tool "$file" > /dev/null || return 1
    grep -q '"type": "PostgreSQL"' "$file" || return 1
    grep -q "\"pg_dump_path\": \"/usr/libexec/postgresql${client_major}/pg_dump\"" "$file"
}

# Every regular file under a directory has mode 0600.
validate_private() {
    local dir="$1"
    docker run --rm -v "$(pwd)/snapshots:/s:ro" alpine:3.24 \
        sh -c "[ -z \"\$(find /s/$dir -type f ! -perm 600)\" ] && [ -n \"\$(find /s/$dir -type f)\" ]"
}

# pg_dumpall emits CREATE ROLE for the bootstrap superuser too, which a fresh server already
# has, so globals restore without ON_ERROR_STOP and that one error is the only one allowed.
restore_globals() {
    local service="$1" dir="$2"
    gunzip -c "$dir/globals.sql.gz" \
        | docker compose exec -T "$service" psql -U postgres -X -q -d postgres > /dev/null 2> /tmp/pgsnap-globals.err
    ! grep 'ERROR' /tmp/pgsnap-globals.err | grep -qv 'role "postgres" already exists'
}

# Each database dump, with ON_ERROR_STOP, into a database created with its owner if missing.
restore_databases() {
    local service="$1" dir="$2"
    for db in app1 app2 app3; do
        local owner=postgres
        [ "$db" = app2 ] && owner=app_owner
        query_in "$service" postgres "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1 \
            || query_in "$service" postgres "CREATE DATABASE $db OWNER $owner" || return 1
        gunzip -c "$dir/$db.gz" | psql_in "$service" -d "$db" || return 1
    done
}

validate_restored() {
    local service="$1"
    [ "$(query_in "$service" app1 'SELECT count(*) FROM users')" = 2 ] || return 1
    [ "$(query_in "$service" app1 'SELECT count(*) FROM cache_data')" = 0 ] || return 1
    [ "$(query_in "$service" app1 "SELECT encode(secret, 'hex') = encode(digest('alice', 'sha256'), 'hex') FROM users WHERE id = 1")" = t ] || return 1
    [ "$(query_in "$service" app2 'SELECT count(*) FROM posts')" = 2 ] || return 1
    [ "$(query_in "$service" app2 "SELECT tableowner FROM pg_tables WHERE tablename = 'posts'")" = app_owner ] || return 1
    [ "$(query_in "$service" app3 'SELECT count(*) FROM orders')" = 2 ]
}

echo "=================================================="
echo "PostgreSQL Snapshot Image - Test Suite"
echo "=================================================="
echo ""

echo "Step 1/4: Cleaning up old containers and snapshots..."
docker compose down -v > /dev/null 2>&1 || true
docker run --rm -v "$(pwd):/w" alpine:3.24 sh -c "rm -rf /w/snapshots /w/view && mkdir -p /w/snapshots"
echo -e "${GREEN}Cleanup complete${NC}"
echo ""

echo "Step 2/4: Building the image..."
# BUILD_NETWORK=host helps where containers cannot resolve the Alpine mirrors (some VPNs).
docker build ${BUILD_NETWORK:+--network "$BUILD_NETWORK"} -t postgres-snapshot:test ..
echo -e "${GREEN}Image built${NC}"
echo ""

echo "Step 3/4: Starting PostgreSQL 17 and 18, source and restore servers..."
if ! docker compose up -d --wait pg17 pg18 pg17-restore pg18-restore; then
    echo -e "${RED}A server did not become healthy; its logs follow${NC}"
    docker compose logs pg17 pg18 pg17-restore pg18-restore
    docker compose down -v > /dev/null 2>&1
    exit 1
fi
echo -e "${GREEN}Servers healthy${NC}"
echo ""

echo "Step 4/4: Running tests..."
echo ""

# Explicit list, struct tables, globals; one run per server major.
snapshot snapshot-multiple-17 hourly > /dev/null 2>&1 || true
snapshot snapshot-multiple-18 hourly > /dev/null 2>&1 || true
snapshot snapshot-all hourly > /dev/null 2>&1 || true
snapshot snapshot-per-db hourly > /dev/null 2>&1 || true
snapshot snapshot-combined hourly > /dev/null 2>&1 || true
refresh_view

for v in 17 18; do
    D=$VIEW/multiple-$v/hourly.0/postgres
    run_test "PG$v: app1 dump" "validate_dump $D/app1.gz"
    run_test "PG$v: app2 dump" "validate_dump $D/app2.gz"
    run_test "PG$v: app3 dump" "validate_dump $D/app3.gz"
    run_test "PG$v: cache_data is structure-only" "validate_structure_only $D/app1.gz public.cache_data"
    run_test "PG$v: cache_pages is structure-only" "validate_structure_only $D/app1.gz public.cache_pages"
    run_test "PG$v: sessions is structure-only" "validate_structure_only $D/app1.gz public.sessions"
    run_test "PG$v: users keeps its data" "validate_has_data $D/app1.gz public.users"
    run_test "PG$v: globals include app_owner" "gunzip -c $D/globals.sql.gz | grep -q 'CREATE ROLE app_owner'"
    run_test "PG$v: metadata names the matching client" "validate_metadata $D/snapshot-metadata.json $v"
    run_test "PG$v: dump uses --clean --if-exists" "gunzip -c $D/app1.gz | grep -q 'DROP TABLE IF EXISTS public.users'"
done

D=$VIEW/all/hourly.0/postgres
run_test "Discovery: app1, app2, Mixed-Case and postgres dumped" "validate_dump $D/app1.gz && validate_dump $D/app2.gz && validate_dump $D/Mixed-Case.gz && validate_dump $D/postgres.gz"
run_test "Discovery: excluded app3 is absent" "[ ! -e $D/app3.gz ]"
run_test "Discovery: no globals unless asked" "[ ! -e $D/globals.sql.gz ]"

D=$VIEW/per-db/hourly.0/postgres
run_test "Per-DB: app1 watchdog is structure-only" "validate_structure_only $D/app1.gz public.watchdog"
run_test "Per-DB: app1 users keeps its data" "validate_has_data $D/app1.gz public.users"
run_test "Per-DB: app2 temp_files is structure-only" "validate_structure_only $D/app2.gz public.temp_files"
run_test "Per-DB: app2 posts keeps its data" "validate_has_data $D/app2.gz public.posts"
run_test "Per-DB: quoted table in Mixed-Case is structure-only" "validate_structure_only $D/Mixed-Case.gz 'public.\"Audit Log\"'"
run_test "Per-DB: Mixed-Case notes keeps its data" "validate_has_data $D/Mixed-Case.gz public.notes"

D=$VIEW/combined/hourly.0/postgres
run_test "Combined: ALL_DATABASES.gz is a pg_dumpall dump" "gunzip -c $D/ALL_DATABASES.gz | grep -q 'PostgreSQL database cluster dump complete'"
run_test "Combined: includes roles and app2" "gunzip -c $D/ALL_DATABASES.gz | grep -q 'CREATE ROLE app_owner' && gunzip -c $D/ALL_DATABASES.gz | grep -q 'CREATE DATABASE app2'"
run_test "Combined: excluded app3 is absent" "! gunzip -c $D/ALL_DATABASES.gz | grep -q 'CREATE DATABASE app3'"
run_test "Combined: per-database files still written" "validate_dump $D/app1.gz"

run_test "Snapshot files are mode 0600" "validate_private multiple-18"

# Disaster recovery: empty server of the same major, globals then databases.
for v in 17 18; do
    D=$VIEW/multiple-$v/hourly.0/postgres
    run_test "PG$v: restore into an empty server" "restore_globals pg$v-restore $D && restore_databases pg$v-restore $D"
    run_test "PG$v: restored data, owners and extension" "validate_restored pg$v-restore"
    run_test "PG$v: restore again over the existing databases" "restore_databases pg$v-restore $D && validate_restored pg$v-restore"
done

# Rotation: only the lowest retained level dumps; higher levels only promote.
R=$VIEW/rotation
snapshot snapshot-rotation daily > /tmp/pgsnap-rotation-daily1.log 2>&1 || true
sleep 1
snapshot snapshot-rotation daily > /tmp/pgsnap-rotation-daily2.log 2>&1 || true
refresh_view
run_test "Rotation: lowest level (daily) dumps live data" "grep -q 'PostgreSQL Snapshot Script' /tmp/pgsnap-rotation-daily2.log && validate_dump $R/daily.0/postgres/app1.gz"
run_test "Rotation: lowest level rotates into daily.1" "[ -f $R/daily.1/postgres/snapshot-metadata.json ]"
cp $R/daily.1/postgres/snapshot-metadata.json /tmp/pgsnap-oldest-daily.json
cp $R/.sync/postgres/snapshot-metadata.json /tmp/pgsnap-sync-before.json
snapshot snapshot-rotation weekly > /tmp/pgsnap-rotation-weekly.log 2>&1 || true
refresh_view
run_test "Rotation: higher level (weekly) does not dump" "! grep -q 'PostgreSQL Snapshot Script' /tmp/pgsnap-rotation-weekly.log && grep -q 'Skipping sync' /tmp/pgsnap-rotation-weekly.log"
run_test "Rotation: higher level leaves .sync untouched" "cmp -s $R/.sync/postgres/snapshot-metadata.json /tmp/pgsnap-sync-before.json"
run_test "Rotation: weekly promotes the oldest daily" "cmp -s $R/weekly.0/postgres/snapshot-metadata.json /tmp/pgsnap-oldest-daily.json && [ ! -e $R/daily.1 ] && [ -d $R/daily.0 ]"
run_test "Rotation: promoted weekly snapshot is valid" "validate_dump $R/weekly.0/postgres/app1.gz"

# Failure: a failed run exits non-zero, rotates nothing, and leaves the last good snapshot.
F=$VIEW/failure
snapshot snapshot-failure-good daily > /dev/null 2>&1 || true
refresh_view
cp $F/daily.0/postgres/snapshot-metadata.json /tmp/pgsnap-good.json
BAD_STATUS=0
snapshot snapshot-failure-bad daily > /tmp/pgsnap-failure-bad.log 2>&1 || BAD_STATUS=$?
refresh_view
run_test "Failure: the run exits non-zero" "[ $BAD_STATUS -ne 0 ]"
run_test "Failure: the error names the missing database" "grep -q 'database \"nosuchdb\" does not exist' /tmp/pgsnap-failure-bad.log"
run_test "Failure: rsnapshot rolled .sync back" "grep -q 'Rolling back' /tmp/pgsnap-failure-bad.log && cmp -s $F/.sync/postgres/snapshot-metadata.json /tmp/pgsnap-good.json"
run_test "Failure: no rotation, so no duplicate generation" "[ ! -e $F/daily.1 ] && cmp -s $F/daily.0/postgres/snapshot-metadata.json /tmp/pgsnap-good.json"
run_test "Failure: no credentials in the log" "! grep -q 'rootpassword' /tmp/pgsnap-failure-bad.log"

# Lock wait: hold an ACCESS EXCLUSIVE lock and expect pg_dump to give up quickly.
docker compose exec -T pg18 psql -U postgres -X -q -d app3 -c "BEGIN; LOCK TABLE orders IN ACCESS EXCLUSIVE MODE; SELECT pg_sleep(30); COMMIT;" > /dev/null 2>&1 &
LOCK_PID=$!
sleep 2
LOCK_START=$(date +%s)
snapshot snapshot-lock hourly > /tmp/pgsnap-lock.log 2>&1 || true
LOCK_ELAPSED=$(( $(date +%s) - LOCK_START ))
kill $LOCK_PID 2>/dev/null || true
wait $LOCK_PID 2>/dev/null || true
run_test "Lock wait: dump fails on a held lock" "grep -q 'canceling statement due to statement timeout' /tmp/pgsnap-lock.log && grep -q 'IN ACCESS SHARE MODE' /tmp/pgsnap-lock.log"
run_test "Lock wait: it fails fast, not after the lock is released" "[ $LOCK_ELAPSED -lt 25 ]"

rm -f /tmp/pgsnap-*.log /tmp/pgsnap-*.json

echo ""
echo "=================================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ($TESTS_PASSED/$TESTS_TOTAL)${NC}"
else
    echo -e "${RED}Some tests failed. ($TESTS_PASSED/$TESTS_TOTAL passed)${NC}"
fi
echo "=================================================="
echo ""

echo "Cleaning up containers..."
docker compose down -v > /dev/null 2>&1
echo -e "${GREEN}Cleanup complete${NC}"

exit $FAILED
