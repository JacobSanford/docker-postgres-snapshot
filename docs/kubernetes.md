---
title: Kubernetes Deployment
description: Kubernetes CronJob configurations for automated PostgreSQL snapshots with Secret and PersistentVolumeClaim examples
audience: users
doc_type: guide
tags: [kubernetes, k8s, cronjob, deployment, scheduling]
lastReviewed: 2026-10-30
version: 1.x
---

# Kubernetes Deployment

Schedule snapshots with one [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/){target="_blank"} per retention level. Each CronJob runs the image with its level as the only argument.

!!! warning "Your Responsibility"
    Please review the [Important Considerations](important-considerations.md) document. This package has not been reviewed for all possible use cases and environments. It should be considered an example, rather than a production-ready tool. Please ensure that you audit this package and how you deploy it against your specific environment and requirements.

## Basic Components

### Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-snapshot-config
data:
  DB_HOSTNAME: "postgres.default.svc.cluster.local"
  DB_PORT: "5432"
  DB_SNAPSHOT_ALL_DATABASES: "true"
  DB_SNAPSHOT_GLOBALS: "true"
  RSNAPSHOT_RETAIN_HOURLY: "0"
  RSNAPSHOT_RETAIN_DAILY: "7"
  RSNAPSHOT_RETAIN_WEEKLY: "4"
  RSNAPSHOT_RETAIN_MONTHLY: "12"
```

### Credentials

Reference the same Secret the database itself uses, so there is one source for the password:

```yaml
env:
  - name: DB_USER_NAME
    valueFrom:
      secretKeyRef:
        name: myapp
        key: postgres-user
  - name: DB_USER_PASSWORD
    valueFrom:
      secretKeyRef:
        name: myapp
        key: postgres-password
```

### Storage

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-snapshot-storage
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
```

Use storage that is not on the database's own node or disk; a snapshot that shares the database's failure domain does not protect against losing it.

## CronJob

The daily level, which is the lowest retained level in the configuration above and so the only one that dumps:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-snapshot-daily
spec:
  schedule: "30 2 * * *"
  concurrencyPolicy: Forbid
  startingDeadlineSeconds: 480
  jobTemplate:
    spec:
      backoffLimit: 0
      activeDeadlineSeconds: 7200
      ttlSecondsAfterFinished: 604800
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: postgres-snapshot
              image: ghcr.io/jacobsanford/postgres-snapshot:1.x
              args: ["daily"]
              envFrom:
                - configMapRef:
                    name: postgres-snapshot-config
              env:
                - name: DB_USER_NAME
                  valueFrom:
                    secretKeyRef: {name: myapp, key: postgres-user}
                - name: DB_USER_PASSWORD
                  valueFrom:
                    secretKeyRef: {name: myapp, key: postgres-password}
              volumeMounts:
                - name: snapshot-storage
                  mountPath: /data
          volumes:
            - name: snapshot-storage
              persistentVolumeClaim:
                claimName: postgres-snapshot-storage
```

Create `weekly` (`"30 5 * * 0"`) and `monthly` (`"30 7 1 * *"`) CronJobs the same way, changing only the name, schedule and argument. Schedule them after the daily run so the two never overlap: rsnapshot's lock file lives inside each container and does not protect one Job from another.

Notes on the Job settings:

- `restartPolicy: Never` with `backoffLimit: 0` keeps a failed run from retrying into the same failure. See [Important Considerations](important-considerations.md).
- `concurrencyPolicy: Forbid` together with `activeDeadlineSeconds` keeps one hung run from blocking every later one forever: the deadline ends it and the next schedule runs.

## Next Steps

- **[Configuration Reference](configuration.md)** - Every environment variable
- **[Restoring Snapshots](restoration.md)** - Disaster recovery
