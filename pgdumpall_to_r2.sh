#!/usr/bin/env bash
set -euo pipefail

# to run this every day on 3AM write this: crontab -e
# 0 3 * * 0 ~/devops/pgdumpall_to_r2.sh >> /var/log/pg_backup.log 2>&1

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

curl -X 'POST' \
  'https://notify.leanderziehm.com/notify/me' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "text": "Backup completed at $(date)"
}'


