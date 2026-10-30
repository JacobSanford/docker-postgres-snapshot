---
title: Snapshot Consistency
description: What point-in-time consistency pg_dump provides within and across databases
audience: users
doc_type: reference
tags: [consistency, mvcc, transactions, data-integrity]
lastReviewed: 2026-10-30
version: 1.x
---

# Snapshot Consistency

## Within a Database
`pg_dump` reads the whole database inside one transaction at the `REPEATABLE READ` isolation level, so every table in a dump reflects the same moment. Relationships between tables are intact, and this holds for every table regardless of how it is stored. Reads and writes continue while the dump runs.

## Across Databases
Each database is dumped separately, one after another, so two databases from the same run reflect different moments. `ALL_DATABASES.gz` is built the same way by `pg_dumpall`. If an application keeps related data in more than one database, a restore of that run can pair data that never coexisted.

## Globals
`globals.sql.gz` is taken after the database dumps. A role created or dropped while the run was in progress may be missing from it or present without objects.

## Not Used
`--serializable-deferrable` is not used. It guarantees a dump that is consistent with every serializable transaction, at the cost of waiting for a safe moment to start, and matters only for applications that rely on `SERIALIZABLE` isolation. See the [pg_dump documentation](https://www.postgresql.org/docs/current/app-pgdump.html){target="_blank"}.
