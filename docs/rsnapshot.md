---
title: Understanding the rsnapshot Configuration
description: How rsnapshot frequency labels, snapshot rotation and failed runs work in docker-postgres-snapshot
audience: users
doc_type: reference
tags: [rsnapshot, configuration, rotation, retention, scheduling]
lastReviewed: 2026-10-30
version: 1.x
---

# Understanding the rsnapshot Configuration

## 'Frequency' Labels
The environment variable names and rsnapshot configuration use the terms `hourly`, `daily`, `weekly`, and `monthly` for different retention levels:

```
retain	hourly	RSNAPSHOT_RETAIN_HOURLY
retain	daily	RSNAPSHOT_RETAIN_DAILY
retain	weekly	RSNAPSHOT_RETAIN_WEEKLY
retain	monthly	RSNAPSHOT_RETAIN_MONTHLY
```

__rsnapshot does not understand time__. These are labels for separate retention groups. How often each level runs is decided only by how often you run the image with that argument (for example, from cron).

## Snapshot Rotation
The image uses rsnapshot's standard rotation with `sync_first 1`. Only the **lowest retained level** (the first `retain` line left in the configuration, normally `hourly`, or `daily` when `RSNAPSHOT_RETAIN_HOURLY` is `0`) dumps the live databases. Every higher level promotes the oldest snapshot of the level below it and does not connect to the database at all.

With `RSNAPSHOT_RETAIN_HOURLY=0` and the default daily, weekly and monthly retention, running the image with:

* `daily` dumps into `.sync`, rotates the daily set (daily.5 → daily.6, ..., daily.0 → daily.1), and makes the new dump daily.0.
* `weekly` rotates the weekly set and moves the oldest daily (daily.6) to weekly.0. Nothing is dumped. Until seven dailies exist there is nothing to promote, and rsnapshot logs `daily.6 not present (yet), nothing to copy`.
* `monthly` does the same with the oldest weekly (weekly.3).

A weekly or monthly snapshot is therefore the dump taken by the lowest level, and its `snapshot-metadata.json` records that original run, including `"frequency": "daily"`.

Every level you schedule must have a non-zero retention, and the lowest level must run often enough to feed the levels above it. A level that is retained but never run becomes the lowest level, and then nothing is ever promoted. Set its retention to `0`.

## Failed Runs
rsnapshot runs the dump script with its working directory in `<snapshot_root>/tmp`, then copies the results into `.sync`. When the script exits non-zero, rsnapshot **rolls `.sync` back** to the newest snapshot of the lowest level, discarding every file from that run, including the databases that did dump successfully.

The image then stops without rotating and exits with rsnapshot's non-zero status. Rotating at that point would only create a copy of the previous snapshot and push the oldest distinct one out of retention. The result of a failed run is that nothing changes on disk and the orchestrator sees a failure.
