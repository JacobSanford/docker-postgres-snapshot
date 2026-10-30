---
title: Docker Compose Examples
description: Sample Docker Compose configurations for explicit lists, discovery, globals and structure-only tables
audience: users
doc_type: guide
tags: [docker-compose, examples, deployment, configuration]
lastReviewed: 2026-10-30
version: 1.x
---

# Docker Compose Examples

!!! warning "Your Responsibility"
    Please review the [Important Considerations](important-considerations.md) document. This package has not been reviewed for all possible use cases and environments. It should be considered an example, rather than a production-ready tool. Please ensure that you audit this package and how you deploy it against your specific environment and requirements.

## Drop-In Example

```yaml
services:
  postgres:
    [...]

  postgres-snapshot:
    image: ghcr.io/jacobsanford/postgres-snapshot:1.x
    restart: "no"
    environment:
      DB_HOSTNAME: postgres
      DB_USER_NAME: postgres
      DB_USER_PASSWORD: changeme
      DB_SNAPSHOT_ALL_DATABASES: "true"
      DB_SNAPSHOT_GLOBALS: "true"
      RSNAPSHOT_RETAIN_HOURLY: 24
      RSNAPSHOT_RETAIN_DAILY: 14
      RSNAPSHOT_RETAIN_WEEKLY: 8
      RSNAPSHOT_RETAIN_MONTHLY: 12
    volumes:
      - ./snapshots:/data
    depends_on:
      postgres:
        condition: service_healthy
```

## Other Examples

### Specific Databases

```yaml
  postgres-snapshot:
    image: ghcr.io/jacobsanford/postgres-snapshot:1.x
    restart: "no"
    environment:
      DB_HOSTNAME: postgres
      DB_USER_NAME: postgres
      DB_USER_PASSWORD: changeme
      DB_DATABASES: "app1,app2,app3"
      DB_STRUCT_TABLES: "cache_*,sessions"
    volumes:
      - ./snapshots:/data
```

### Discovery With Exclusions

```yaml
  postgres-snapshot:
    image: ghcr.io/jacobsanford/postgres-snapshot:1.x
    restart: "no"
    environment:
      DB_HOSTNAME: postgres
      DB_USER_NAME: postgres
      DB_USER_PASSWORD: changeme
      DB_SNAPSHOT_ALL_DATABASES: "true"
      DB_EXCLUDE_DATABASES: "scratch,reporting_copy"
    volumes:
      - ./snapshots:/data
```

### Structure-Only Tables Per Database

```yaml
  postgres-snapshot:
    image: ghcr.io/jacobsanford/postgres-snapshot:1.x
    restart: "no"
    environment:
      DB_HOSTNAME: postgres
      DB_USER_NAME: postgres
      DB_USER_PASSWORD: changeme
      DB_DATABASES: "app1,app2"
      DB_STRUCT_TABLES_APP1: "cache_*,sessions,watchdog"
      DB_STRUCT_TABLES_APP2: "temp_*,cache"
    volumes:
      - ./snapshots:/data
```

## Running Snapshots

```bash
docker compose run --rm <service-name> <frequency>
```

Where `<frequency>` is one of `hourly`, `daily`, `weekly` or `monthly`.

## Next Steps

- **[Configuration Reference](configuration.md)** - Every environment variable
- **[Kubernetes Examples](kubernetes.md)** - CronJob scheduling
