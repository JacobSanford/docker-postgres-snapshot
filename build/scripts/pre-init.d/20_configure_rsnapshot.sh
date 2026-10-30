#!/usr/bin/env sh
sed -i "s|DB_DUMP_LOCATION|$DB_DUMP_LOCATION|g" /etc/rsnapshot.conf
sed -i "s|RSNAPSHOT_VERBOSE|$RSNAPSHOT_VERBOSE|g" /etc/rsnapshot.conf
sed -i "s|RSNAPSHOT_LOGLEVEL|$RSNAPSHOT_LOGLEVEL|g" /etc/rsnapshot.conf

for TIMEFRAME in RSNAPSHOT_RETAIN_HOURLY RSNAPSHOT_RETAIN_DAILY RSNAPSHOT_RETAIN_WEEKLY RSNAPSHOT_RETAIN_MONTHLY
do
  eval TIMEFRAME_VALUE=\$$TIMEFRAME
  if [ "$TIMEFRAME_VALUE" == '0' ]; then
    sed -i "/$TIMEFRAME/d" /etc/rsnapshot.conf
  else
    sed -i "s|$TIMEFRAME|$TIMEFRAME_VALUE|g" /etc/rsnapshot.conf
  fi
done
