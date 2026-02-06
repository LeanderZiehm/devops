#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
BACKUP_DIR="$HOME/backups/postgres"
RETENTION_DAYS=30

RCLONE_REMOTE="dropbox:backups/postgres/${HOSTNAME}"
HOSTNAME="$(hostname -s)"
PG_USER="postgres"

TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
DUMP_FILE="pg_dumpall_${TIMESTAMP}.sql"
ARCHIVE_FILE="${DUMP_FILE}.gz"

# ---- ensure dirs ----
mkdir -p "${BACKUP_DIR}"

# ---- dump ----
sudo -u "${PG_USER}" pg_dumpall > "${BACKUP_DIR}/${DUMP_FILE}"

# ---- compress ----
gzip "${BACKUP_DIR}/${DUMP_FILE}"

# ---- cleanup old local backups ----
find "${BACKUP_DIR}" -type f -name "*.gz" -mtime +"${RETENTION_DAYS}" -delete

# ---- sync to R2 (rsync-style) ----
rclone copy \
  "${BACKUP_DIR}" \
  "${RCLONE_REMOTE}" \
  --ignore-existing \
  --progress

echo "Backup completed at $(date)"
