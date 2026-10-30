---
title: Quick Start Guide
description: Get up and running with docker-postgres-snapshot in 5 minutes with Docker CLI, Docker Compose, and cron scheduling examples
audience: users
doc_type: quickstart
tags: [quickstart, getting-started, docker, docker-compose, cron]
lastReviewed: 2026-10-30
version: 1.x
---

# Quick Start Guide

Get up and running with docker-postgres-snapshot in 5 minutes.

!!! warning "Your Responsibility"
    Please review the [Important Considerations](important-considerations.md) document. This package has not been reviewed for all possible use cases and environments. It should be considered an example, rather than a production-ready tool. Please ensure that you audit this package and how you deploy it against your specific environment and requirements.

## Basic Usage

docker-postgres-snapshot accepts one argument to specify the snapshot frequency:

- `hourly` - Performs an hourly snapshot
- `daily` - Performs a daily snapshot
- `weekly` - Performs a weekly snapshot
- `monthly` - Performs a monthly snapshot

These are labels passed to rsnapshot, which handles snapshot rotation based on your retention configuration. Only the lowest retained level (`hourly` by default) dumps the databases; higher levels promote the oldest snapshot of the level below. If you do not schedule `hourly`, set `RSNAPSHOT_RETAIN_HOURLY=0`. See [Understanding the rsnapshot Configuration](rsnapshot.md).

## Docker Run Example

A minimal example snapshotting one database:

```bash
docker run --rm \
  -e DB_HOSTNAME=postgres.example.com \
  -e DB_PORT=5432 \
  -e DB_USER_NAME=postgres \
  -e DB_USER_PASSWORD=secure_password \
  -e DB_DATABASES=myapp \
  -v /path/to/snapshots:/data \
  ghcr.io/jacobsanford/postgres-snapshot:1.x hourly
```

This creates a snapshot in `/path/to/snapshots/hourly.0/postgres/myapp.gz`.

## Docker Compose Quick Example

Create a `docker-compose.yml`:

```yaml
services:
  postgres-snapshot:
    image: ghcr.io/jacobsanford/postgres-snapshot:1.x
    restart: "no"
    environment:
      DB_HOSTNAME: postgres
      DB_USER_NAME: postgres
      DB_USER_PASSWORD: changeme
      DB_SNAPSHOT_ALL_DATABASES: "true"
      DB_SNAPSHOT_GLOBALS: "true"
    volumes:
      - ./snapshots:/data
```

Run a snapshot:

```bash
docker compose run --rm postgres-snapshot hourly
```

### Scheduling with Cron

To run automated snapshots, add to your [crontab](https://man7.org/linux/man-pages/man5/crontab.5.html){target="_blank"}:

```bash
# Hourly snapshots at minute 0
0 * * * * cd /path/to/compose && docker compose run --rm postgres-snapshot hourly

# Daily snapshots at 2am
0 2 * * * cd /path/to/compose && docker compose run --rm postgres-snapshot daily

# Weekly snapshots on Sunday at 3am
0 3 * * 0 cd /path/to/compose && docker compose run --rm postgres-snapshot weekly

# Monthly snapshots on the 1st at 4am
0 4 1 * * cd /path/to/compose && docker compose run --rm postgres-snapshot monthly
```

## Understanding Snapshot Output

```
/data/
├── .sync/          # The last dump taken by the lowest level
├── hourly.0/       # Most recent hourly snapshot
│   └── postgres/
│       ├── myapp.gz
│       ├── globals.sql.gz
│       └── snapshot-metadata.json
├── hourly.1/       # Previous hourly snapshot
├── daily.0/        # Most recent daily snapshot
└── weekly.0/       # Most recent weekly snapshot
```

The `.0` directories contain the newest snapshots. Older snapshots are rotated to `.1`, `.2`, and so on, according to your retention policy. Unchanged files are hard links between generations, so they take no extra space.

## Next Steps

- **[Configuration](configuration.md)** - Every environment variable
- **[Restoring Snapshots](restoration.md)** - Test a restore immediately after the first snapshot
- **[Kubernetes](kubernetes.md)** - Deploy with CronJobs
