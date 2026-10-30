# docker-postgres-snapshot

A [Docker](https://www.docker.com) image that wraps [pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html) and [rsnapshot](https://rsnapshot.org) to provide a drop-in solution for periodic snapshots of PostgreSQL databases with automated rotation and retention.

The primary goals of docker-postgres-snapshot are reliability, simplicity, and ease of use. It is the PostgreSQL counterpart of [docker-mariadb-snapshot](https://github.com/JacobSanford/docker-mariadb-snapshot) and keeps its layout, rotation model and configuration style.

## Documentation

Read the [full documentation](https://jacobsanford.github.io/docker-postgres-snapshot/1.x/).

- **[Quick Start Guide](https://jacobsanford.github.io/docker-postgres-snapshot/1.x/quickstart)** - Get started in 5 minutes
- **[Configuration Reference](https://jacobsanford.github.io/docker-postgres-snapshot/1.x/configuration)** - Complete environment variable guide
- **[Restoring Snapshots](https://jacobsanford.github.io/docker-postgres-snapshot/1.x/restoration)** - Disaster recovery and in-place restores
- **[Kubernetes Deployment](https://jacobsanford.github.io/docker-postgres-snapshot/1.x/kubernetes)** - CronJob configurations
- **[Running Tests](https://jacobsanford.github.io/docker-postgres-snapshot/1.x/running-tests)** - Developer testing guide

## Quick Start

```bash
docker run --rm \
  -e DB_HOSTNAME=postgres.example.com \
  -e DB_USER_NAME=postgres \
  -e DB_USER_PASSWORD=secure_password \
  -e DB_SNAPSHOT_ALL_DATABASES=true \
  -e DB_SNAPSHOT_GLOBALS=true \
  -v /output/path:/data \
  ghcr.io/jacobsanford/postgres-snapshot:1.x hourly
```

This writes `/output/path/hourly.0/postgres/<database>.gz`, `globals.sql.gz` and `snapshot-metadata.json`.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
