---
title: Important Considerations
description: Security, data integrity, failure handling and operational considerations for using docker-postgres-snapshot in production
audience: users
doc_type: reference
tags: [security, best-practices, considerations, production, data-integrity, failures]
lastReviewed: 2026-10-30
version: 1.x
---

# Important Considerations

!!! info "Please Read"
    These considerations help you judge whether docker-postgres-snapshot suits your environment.

docker-postgres-snapshot takes logical dumps. It is not point-in-time recovery: anything written after the last successful dump is not in any snapshot. If you need recovery to an arbitrary moment, use continuous archiving of the write-ahead log instead of, or as well as, this image.

## Testing Snapshot Restorations
Test a restore __immediately after the first snapshots exist__, in a non-production environment, following [Restoring Snapshots](restoration.md) as if the original were gone. Repeat it periodically.

## Sensitive Data
Snapshots are plain SQL and contain everything in the database, including role password hashes in `globals.sql.gz`. The image writes every file with mode `0600`. Restrict access to wherever the snapshots are stored.

## Failed Runs Exit Non-Zero and Change Nothing
If any part of a run fails (one database, the globals, or the combined file), the image exits with a non-zero status. rsnapshot rolls the run back, discarding the dumps that did succeed, and the image skips rotation. The snapshots on disk are exactly as they were before the run. See [Understanding the rsnapshot Configuration](rsnapshot.md).

The consequence: **a failure that repeats every run freezes your snapshots at the last good one**, while each run reports failure. For example, enabling `DB_SNAPSHOT_GLOBALS` with a role that is not a superuser fails every night. Watch the exit status of every run, and alert when the newest successful snapshot is older than you expect.

## Container Restart Policies
Do not let the orchestrator retry a failed run automatically; a retry repeats the same failure and adds load to the server.

### docker-compose
```yaml
service:
    [...]
    restart: "no"
```

### Kubernetes
```yaml
    restartPolicy: Never
    backoffLimit: 0
    activeDeadlineSeconds: 7200
```

With `concurrencyPolicy: Forbid`, a run that hangs blocks every later run until it ends; `activeDeadlineSeconds` makes sure it does.

## Locks Taken During a Dump
`pg_dump` takes an `ACCESS SHARE` lock on every table it dumps and holds it for the whole dump. That does not block reads or writes, but it blocks schema changes (for example, a migration's `ALTER TABLE`), and statements queued behind a waiting schema change wait too. `DB_LOCK_WAIT_TIMEOUT` makes the dump give up if it cannot get its locks, instead of queueing behind a schema change already in progress. Schedule dumps away from deployments.

## Dump Options
Each database is dumped with:

```bash
    --format=plain
    --clean
    --if-exists
    --lock-wait-timeout=${DB_LOCK_WAIT_TIMEOUT}
    --exclude-table-data=<each structure-only table>
```

The dump is written uncompressed to the container's `/tmp`, then compressed with `gzip`. It is never piped straight into the compressor, so the server's snapshot and locks are released as soon as the dump ends.

## Consistency
Each database is captured as of a single moment. Different databases are captured at different moments. See [Snapshot Consistency](consistency.md).
