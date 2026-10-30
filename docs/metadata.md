---
title: Snapshot Metadata
description: Understanding the snapshot-metadata.json file written with each snapshot
audience: users
doc_type: reference
tags: [metadata, json, snapshot-info, configuration, troubleshooting]
lastReviewed: 2026-10-30
version: 1.x
---

# Snapshot Metadata

Each run that dumps writes a `snapshot-metadata.json` file beside the dumps, and rsnapshot rotates it with them. A promoted weekly or monthly snapshot keeps the metadata of the run that created it, so its `frequency` is the lowest level's (for example `daily`).

**Contents:**

- **Snapshot information**: start time, end time, duration in seconds, and the level that ran
- **Database server**: `PostgreSQL`, its version, and the full `version()` string
- **Client information**: the path and version of the `pg_dump` used, which shows the major version selected
- **Configuration**: the settings that shaped the snapshot, without credentials

**Example:**
```json
{
  "snapshot_info": {
    "start_time": "2026-10-30T19:03:31Z",
    "end_time": "2026-10-30T19:03:31Z",
    "duration_seconds": 0,
    "frequency": "hourly"
  },
  "database_server": {
    "type": "PostgreSQL",
    "version": "18.6",
    "version_string": "PostgreSQL 18.6 on x86_64-pc-linux-musl, compiled by gcc (Alpine 15.2.0) 15.2.0, 64-bit"
  },
  "client_info": {
    "pg_dump_path": "/usr/libexec/postgresql18/pg_dump",
    "pg_dump_version": "pg_dump (PostgreSQL) 18.6"
  },
  "configuration": {
    "DB_HOSTNAME": "pg18",
    "DB_PORT": "5432",
    "DB_DATABASES": "app1,app2,app3",
    "DB_SNAPSHOT_ALL_DATABASES": "",
    "DB_SNAPSHOT_COMBINED": "",
    "DB_SNAPSHOT_GLOBALS": "true",
    "DB_EXCLUDE_DATABASES": "",
    "DB_STRUCT_TABLES": "cache_*,sessions",
    "DB_SSLMODE": "prefer",
    "DB_LOCK_WAIT_TIMEOUT": "10min",
    "RSNAPSHOT_RETAIN_HOURLY": "8",
    "RSNAPSHOT_RETAIN_DAILY": "7",
    "RSNAPSHOT_RETAIN_WEEKLY": "4",
    "RSNAPSHOT_RETAIN_MONTHLY": "6",
    "GZIP_COMPRESSION_LEVEL": "6"
  }
}
```

**Security note:** the file never contains `DB_USER_NAME` or `DB_USER_PASSWORD`.
