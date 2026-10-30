---
title: docker-postgres-snapshot Documentation
description: Docker image for periodic PostgreSQL database snapshots with rotation using pg_dump and rsnapshot
audience: users
doc_type: landing
tags: [postgresql, postgres, snapshot, rsnapshot, pg_dump, docker, database]
lastReviewed: 2026-10-30
version: 1.x
---

# docker-postgres-snapshot Documentation

[![CI](https://github.com/JacobSanford/docker-postgres-snapshot/actions/workflows/ci.yml/badge.svg)](https://github.com/JacobSanford/docker-postgres-snapshot/actions/workflows/ci.yml){target="_blank"}

A [Docker](https://www.docker.com){target="_blank"} image that wraps [pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html){target="_blank"} and [rsnapshot](https://rsnapshot.org){target="_blank"} to provide a drop-in solution for periodic snapshots of PostgreSQL databases with automated rotation and retention.

The primary goals of docker-postgres-snapshot are reliability, simplicity, and ease of use. It is the PostgreSQL counterpart of [docker-mariadb-snapshot](https://github.com/JacobSanford/docker-mariadb-snapshot){target="_blank"}.

!!! warning "Your Responsibility"
    Please review the [Important Considerations](important-considerations.md) document. This package has not been reviewed for all possible use cases and environments. It should be considered an example, rather than a production-ready tool. Please ensure that you audit this package and how you deploy it against your specific environment and requirements.

## Compatibility
The image carries the PostgreSQL 17 and 18 clients and dumps each server with the client of its own major version. See [Compatibility](compatibility.md).

## Quick Navigation

- **[Quick Start Guide](quickstart.md)** - Get up and running in 5 minutes
- **[Configuration Reference](configuration.md)** - Complete environment variable documentation
- **[Restoring Snapshots](restoration.md)** - Disaster recovery and in-place restores
- **[Docker Compose Examples](docker-compose.md)** - Sample configurations
- **[Kubernetes Deployment](kubernetes.md)** - CronJob and volume configurations
- **[Running Tests](running-tests.md)** - Developer guide to testing

## How It Works

When run with the lowest retained frequency argument (normally `hourly`), the image:

1. Connects to your PostgreSQL server and picks the `pg_dump` matching the server's major version
2. Selects databases from an explicit list or by discovery
3. Applies structure-only table rules if configured
4. Dumps each database to a plain SQL file in the container's `/tmp`, and compresses it only after `pg_dump` has finished
5. Optionally dumps roles and tablespaces (`globals.sql.gz`) and a single cluster-wide file
6. Writes a `snapshot-metadata.json` file with timing, versions and configuration
7. Rotates snapshots according to retention policies into `hourly.0/`, `hourly.1/`, and so on

When run with a higher level (`daily`, `weekly`, `monthly`), it only promotes the oldest snapshot of the level below; see [Understanding the rsnapshot Configuration](rsnapshot.md). If any dump fails, the run exits non-zero and leaves the existing snapshots untouched; see [Important Considerations](important-considerations.md).

## License

This project is licensed under the MIT License.
