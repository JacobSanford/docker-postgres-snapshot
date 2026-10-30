---
title: Compatibility
description: PostgreSQL server and client version compatibility for docker-postgres-snapshot dumps and restores
audience: users
doc_type: reference
tags: [compatibility, postgresql, versions]
lastReviewed: 2026-10-30
version: 1.x
---

# Compatibility

## Dumping
The image carries the PostgreSQL 17 and 18 clients and dumps each server with the client of the same major version, so the dump contains nothing the server's own version could not have produced. The test suite runs every scenario against both.

A server of any other major version is dumped with the newest client, which logs a warning. `pg_dump` supports servers back to 9.2, so older servers still work; a server newer than every installed client is refused by `pg_dump` itself. The client actually used is recorded in `snapshot-metadata.json`.

To support another major version, add its `postgresqlNN-client` package to the `Dockerfile` and its server to the test suite.

## Restoring
A dump restores into a server of the same major version, which is the case the tests prove. Restoring into a newer major version is the supported PostgreSQL upgrade path. Restoring into an older one is not supported by PostgreSQL and may fail on statements the older server does not know.

Dumps start with `\restrict`, which `psql` gained in the August 2025 minor releases (17.6, 16.10, 15.14, 14.19, 13.22). Restore with a `psql` at least that recent; see [Restoring Snapshots](restoration.md).
