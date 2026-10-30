---
title: Configuration Reference
description: Complete reference for all environment variables and configuration options for docker-postgres-snapshot
audience: users
doc_type: reference
tags: [configuration, environment-variables, settings, retention, database]
lastReviewed: 2026-10-30
version: 1.x
---

# Snapshot Configuration
All configuration options are set via environment variables within the running container.

## rsnapshot Retention Settings
Control how many snapshots rsnapshot retains (follows [rsnapshot retention models](https://wiki.archlinux.org/title/Rsnapshot){target="_blank"}). A value of `0` removes the level entirely; every level that you do not schedule must be `0`. See [Understanding the rsnapshot Configuration](rsnapshot.md).

| Variable | Description | Default |
|----------|-------------|---------|
| `RSNAPSHOT_RETAIN_HOURLY` | Number of hourly snapshots to retain | `8` |
| `RSNAPSHOT_RETAIN_DAILY` | Number of daily snapshots to retain | `7` |
| `RSNAPSHOT_RETAIN_WEEKLY` | Number of weekly snapshots to retain | `4` |
| `RSNAPSHOT_RETAIN_MONTHLY` | Number of monthly snapshots to retain | `6` |

## General Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `GZIP_COMPRESSION_LEVEL` | Level of [gzip compression](https://en.wikipedia.org/wiki/Gzip){target="_blank"} (1-9) | `6` |
| `DB_DUMP_LOCATION` | Directory where snapshots are stored | `/data` |
| `DB_LOCK_WAIT_TIMEOUT` | How long `pg_dump` waits for its shared table locks before failing, in any format `SET statement_timeout` accepts | `10min` |

Each dump is written uncompressed to the container's `/tmp` and compressed only after `pg_dump` has exited, so the database's snapshot and locks are released before compression starts. The container's `/tmp` must therefore hold the largest uncompressed dump.

## PostgreSQL Connection Parameters

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOSTNAME` | Hostname or IP address of the server | `localhost` |
| `DB_PORT` | Port of the server | `5432` |
| `DB_USER_NAME` | Role to connect as | `postgres` |
| `DB_USER_PASSWORD` | Password for that role | (empty) |
| `DB_MAINTENANCE_DATABASE` | Database used for discovery, version checks and `pg_dumpall` | `postgres` |
| `DB_SSLMODE` | libpq [sslmode](https://www.postgresql.org/docs/current/libpq-ssl.html){target="_blank"} | `prefer` |
| `DB_CONNECT_TIMEOUT` | Seconds to wait for a connection | `30` |

### Required Privileges

- Database dumps need read access to everything dumped. On PostgreSQL 14 and newer, a role with the predefined `pg_read_all_data` role is enough.
- `DB_SNAPSHOT_GLOBALS` and `DB_SNAPSHOT_COMBINED` read `pg_authid` and need a **superuser**. With any other role, leave both off: a dump that fails every night freezes the snapshots at the last good run, as described in [Important Considerations](important-considerations.md).

## Client Selection

The image carries the PostgreSQL 17 and 18 clients. Each run reads the server's version and uses the `pg_dump` of the same major version, so a dump restores into the same major version without features the server does not have. For any other server version it uses the newest client and logs a warning; a newer `pg_dump` can dump an older server. The client used is recorded in `snapshot-metadata.json`.

## Database Selection Modes

### Mode 1: Explicit List

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_DATABASES` | Comma-separated list of databases to snapshot | `db1,db2,db3` |

### Mode 2: Discovery

Discover and snapshot every database that accepts connections and is not a template, including `postgres`.

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_SNAPSHOT_ALL_DATABASES` | Set to `true` or `1` to enable discovery | (disabled) |
| `DB_EXCLUDE_DATABASES` | Comma-separated database names to skip, matched exactly | (empty) |
| `DB_SNAPSHOT_COMBINED` | Also write `ALL_DATABASES.gz` with `pg_dumpall` | (disabled) |

If both are set, `DB_DATABASES` wins.

## Structure-Only Tables
Tables whose data is not worth keeping (caches, sessions) can be dumped as structure only.

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_STRUCT_TABLES` | Comma-separated table name patterns for every database | `cache_*,sessions` |
| `DB_STRUCT_TABLES_<NORMALIZED_DB_NAME>` | Patterns for one database, replacing the global list | `cache_*,watchdog` |

**Pattern matching:**

- `*` matches any characters; patterns are matched with SQL `LIKE` against table names in every schema except `pg_catalog` and `information_schema`, so `_` matches any single character.
- Matching is case-sensitive and exact otherwise; a pattern that matches nothing is ignored.
- The table's definition, indexes and constraints are still dumped; only its rows are left out.

`<NORMALIZED_DB_NAME>` is the database name in upper case with every character other than letters, digits and `_` replaced by `_`:

| Database Name | Environment Variable |
|---------------|---------------------|
| `myapp` | `DB_STRUCT_TABLES_MYAPP` |
| `my-app` | `DB_STRUCT_TABLES_MY_APP` |
| `Mixed-Case` | `DB_STRUCT_TABLES_MIXED_CASE` |

## Globals Snapshot

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_SNAPSHOT_GLOBALS` | Set to `true` or `1` to write `globals.sql.gz` with `pg_dumpall --globals-only` | (disabled) |

`globals.sql.gz` holds roles with their password hashes, role memberships and settings, and tablespaces. Per-database dumps reference roles as owners and grantees, so restoring a database onto a new server needs the globals first. See [Restoring Snapshots](restoration.md).
