FROM alpine:3.24

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

ENV GZIP_COMPRESSION_LEVEL=6

ENV DB_DUMP_LOCATION=/data
ENV DB_HOSTNAME=localhost
ENV DB_PORT=5432
ENV DB_MAINTENANCE_DATABASE=postgres
ENV DB_USER_NAME=postgres
ENV DB_USER_PASSWORD=""
ENV DB_DATABASES=""
ENV DB_SNAPSHOT_ALL_DATABASES=""
ENV DB_SNAPSHOT_COMBINED=""
ENV DB_SNAPSHOT_GLOBALS=""
ENV DB_EXCLUDE_DATABASES=""
ENV DB_STRUCT_TABLES=""
ENV DB_SSLMODE=prefer
ENV DB_CONNECT_TIMEOUT=30
ENV DB_LOCK_WAIT_TIMEOUT=10min

ENV RSNAPSHOT_RETAIN_DAILY=7
ENV RSNAPSHOT_RETAIN_HOURLY=8
ENV RSNAPSHOT_RETAIN_MONTHLY=6
ENV RSNAPSHOT_RETAIN_WEEKLY=4
ENV RSNAPSHOT_VERBOSE=2
ENV RSNAPSHOT_LOGLEVEL=3

# One client per server major in use. snapshot.sh picks the client matching the server's major
# version and falls back to the newest installed one. Add a major here when a server moves to it.
RUN apk --update --no-cache add rsnapshot postgresql17-client postgresql18-client && \
  mkdir -p ${DB_DUMP_LOCATION}

COPY ./build/conf/rsnapshot/rsnapshot.conf /etc/rsnapshot.conf
COPY ./build/scripts /scripts

ENTRYPOINT ["/scripts/run.sh"]

LABEL org.opencontainers.image.authors="Jacob Sanford <jsanford@unb.ca>" \
  org.opencontainers.image.description="postgres-snapshot provides PostgreSQL point-in-time snapshots with rsnapshot rotation." \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.source="https://github.com/JacobSanford/docker-postgres-snapshot" \
  org.opencontainers.image.title="postgres-snapshot"
