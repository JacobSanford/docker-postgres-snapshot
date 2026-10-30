#!/usr/bin/env sh
for i in /scripts/pre-init.d/*sh
do
  if [ -e "${i}" ]; then
    echo "[i] pre-init.d - processing $i"
    . "${i}"
  fi
done

FREQUENCY=${1:-hourly}
export SNAPSHOT_FREQUENCY=$FREQUENCY

echo "Configuration:"
cat /etc/rsnapshot.conf
echo "Generating Snapshots..."

# Only the lowest retained level takes a new snapshot of the live data. rsnapshot turns
# .sync into a new generation only for that level; every higher level promotes the oldest
# generation of the level below it. A sync before a higher level's rotation would dump the
# databases and then discard the result, since nothing reads .sync until the lowest level
# next runs and the next sync overwrites it.
LOWEST_LEVEL=$(awk '$1 == "retain" { print $2; exit }' /etc/rsnapshot.conf)

if [ "$FREQUENCY" = "$LOWEST_LEVEL" ]; then
  /usr/bin/rsnapshot -c /etc/rsnapshot.conf sync
  SYNC_STATUS=$?
  # When snapshot.sh fails, rsnapshot rolls .sync back to the newest generation of the lowest
  # level, discarding every dump from this run, and exits non-zero. Rotating then would only
  # add a duplicate of that generation and push the oldest distinct one out, so stop here, and
  # exit non-zero so the orchestrator sees the failure.
  if [ "$SYNC_STATUS" -ne 0 ]; then
    echo "❌ rsnapshot sync exited $SYNC_STATUS; not rotating '$FREQUENCY'. The existing snapshots are unchanged."
    exit "$SYNC_STATUS"
  fi
else
  echo "Skipping sync: '$FREQUENCY' is not the lowest retained level ('$LOWEST_LEVEL'); promoting only."
fi
/usr/bin/rsnapshot -c /etc/rsnapshot.conf "$FREQUENCY"
