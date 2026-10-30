---
title: Restoring Snapshots
description: Disaster recovery onto an empty server and in-place restores from docker-postgres-snapshot snapshots
audience: users
doc_type: guide
tags: [restore, recovery, postgresql, disaster-recovery, roles]
lastReviewed: 2026-10-30
version: 1.x
---

# Restoring Snapshots

!!! warning "Test Restorations First"
    Restore a snapshot into a scratch server as soon as the first one exists, and periodically after that. Each procedure on this page is exercised by the image's own test suite against PostgreSQL 17 and 18.

## What a Snapshot Contains

- **`<database>.gz`** - A plain SQL dump of one database: schemas, tables, data, indexes, constraints, functions, triggers, extensions, owners and privileges. It starts with `DROP ... IF EXISTS` for every object, and it does not create the database itself.
- **`globals.sql.gz`** - Roles, their password hashes, memberships and settings, and tablespaces (if `DB_SNAPSHOT_GLOBALS` was on).
- **`ALL_DATABASES.gz`** - Everything above in one `pg_dumpall` file (if `DB_SNAPSHOT_COMBINED` was on).
- **`snapshot-metadata.json`** - When the dump ran, the server and client versions, and the configuration.

Structure-only tables are restored empty.

## Use a Matching psql

Restore with a `psql` of the dump's major version (see `pg_dump_version` in the metadata) or newer. Dumps start with a `\restrict` line, a protection added in the August 2025 minor releases (17.6, 16.10, 15.14, 14.19, 13.22); an older `psql` is expected to reject it. The image itself carries current clients:

```bash
docker run --rm -i --entrypoint /usr/libexec/postgresql18/psql \
  ghcr.io/jacobsanford/postgres-snapshot:1.x --version
```

## Disaster Recovery Onto an Empty Server

Start an empty server of the same major version, created with the same superuser name as the original. Then:

1. **Globals first.** Owners and grants in the database dumps refer to these roles.

    ```bash
    gunzip -c globals.sql.gz | psql -h NEWHOST -U postgres -d postgres
    ```

    Expect exactly one error, `role "postgres" already exists`, for the superuser the new server was created with. Any other error needs attention before continuing.

2. **Create each database with its original owner.**

    ```bash
    psql -h NEWHOST -U postgres -d postgres -c 'CREATE DATABASE myapp OWNER myapp_owner'
    ```

3. **Restore each dump, stopping at the first error.**

    ```bash
    gunzip -c myapp.gz | psql -h NEWHOST -U postgres -v ON_ERROR_STOP=1 -d myapp
    ```

Restore as a superuser: dumps set owners and create extensions.

## Restoring Into an Existing Database

The dumps drop and recreate every object they contain, so the same command restores over an existing database:

```bash
gunzip -c myapp.gz | psql -h HOST -U postgres -v ON_ERROR_STOP=1 -d myapp
```

Objects in the database that are not in the dump are left in place. Stop the application first; the restore takes locks and replaces tables underneath it.

## Restoring the Combined File

`ALL_DATABASES.gz` drops and recreates every role and database it contains:

```bash
gunzip -c ALL_DATABASES.gz | psql -h HOST -U postgres -d postgres
```

It cannot drop a database that has open connections, or the role you are connected as, so use it on an empty or isolated server.

## Examining Snapshots

```bash
# View the SQL without running it
gunzip -c myapp.gz | less

# Check the file is intact
gunzip -t myapp.gz && echo "File is valid"

# Review metadata
jq . snapshot-metadata.json
```

## Related Documentation

- [Configuration Reference](configuration.md)
- [Important Considerations](important-considerations.md)
- [Snapshot Metadata](metadata.md)
