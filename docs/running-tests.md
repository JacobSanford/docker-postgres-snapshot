---
title: Running Tests
description: Developer guide for running the automated tests that validate docker-postgres-snapshot
audience: developers
doc_type: guide
tags: [testing, development, validation, automated-tests]
lastReviewed: 2026-10-30
version: 1.x
---

# Running Tests

The `testing/` directory holds a self-contained suite for the image. It needs Docker with Compose v2, and `python3` for the JSON check.

```bash
cd testing
./run-tests.sh
```

If containers cannot resolve the Alpine package mirrors during the build (some VPNs cause this), build on the host network:

```bash
BUILD_NETWORK=host ./run-tests.sh
```

The runner:

1. Removes old containers and snapshots
2. Builds the image as `postgres-snapshot:test`
3. Starts PostgreSQL 17 and 18 seeded from `init-db.sql`, plus an empty server of each version for restores
4. Runs every scenario and check
5. Removes the containers

## What the Tests Cover

| Area | What is checked |
|---|---|
| Explicit list | Every database dumped on 17 and 18, complete and valid gzip |
| Client selection | The metadata names the client of the server's own major version |
| Structure-only tables | Global and per-database patterns keep the table definition and drop its rows; a quoted table name with a space in a mixed-case database |
| Discovery | Includes `postgres` and a mixed-case database, honours `DB_EXCLUDE_DATABASES` |
| Combined | `ALL_DATABASES.gz` is a complete `pg_dumpall` dump with roles, without excluded databases |
| Globals | `globals.sql.gz` contains the non-superuser role |
| Permissions | Every snapshot file has mode `0600` |
| Disaster recovery | Globals, then each database, into an empty server of the same major; row counts, a table owned by a non-superuser role, and data from the `pgcrypto` extension |
| In-place restore | The same dumps restored again over the restored databases |
| Rotation | Only the lowest level dumps; weekly promotes the oldest daily |
| Failure | A missing database makes the run exit non-zero, rsnapshot rolls back, nothing rotates, and no password appears in the log |
| Lock wait | A table held in `ACCESS EXCLUSIVE` mode makes the dump fail within `DB_LOCK_WAIT_TIMEOUT`, not after the lock is released |

## Inspecting Snapshots

Snapshot files are written by root with mode `0600`. The runner copies them into `testing/view/`, owned by you, after every run:

```bash
gunzip -c testing/view/multiple-18/hourly.0/postgres/app1.gz | less
```

## Running One Scenario

```bash
cd testing
docker build -t postgres-snapshot:test ..
docker compose up -d --wait pg18
docker compose run --rm snapshot-multiple-18 hourly
```

## Cleanup

```bash
cd testing
docker compose down -v
docker run --rm -v "$(pwd):/w" alpine:3.24 rm -rf /w/snapshots /w/view
```

## Continuous Integration

`.github/workflows/ci.yml` runs the suite on every push and pull request, then builds and pushes the image.
