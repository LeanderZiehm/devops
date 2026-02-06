#!/usr/bin/env bash
set -euo pipefail

# to run this every day on 3AM write this: chmod +x backup-postgres.sh
# crontab -e
# 0 3 * * 0 ~/devops/backup-postgres.sh >> /var/log/pg_backup.log 2>&1

START_TIME="$(date +%s)"
# ---- config ----
BACKUP_DIR="$HOME/backups/postgres"
RETENTION_DAYS=30

HOSTNAME="$(hostname -s)"
RCLONE_REMOTE="dropbox:backups/postgres/${HOSTNAME}"
PG_USER="postgres"

TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
DUMP_FILE="pg_dumpall_${TIMESTAMP}.sql"
ARCHIVE_FILE="${DUMP_FILE}.gz"

trap 'curl -s -X POST https://notify.leanderziehm.com/notify/me \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg text "PostgreSQL backup FAILED on ${HOSTNAME} at $(date -Is)" "{text: \$text}")"' ERR

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
  --stats=1m \
  --log-level NOTICE
  # --progress



echo "Backup completed at $(date)"

# ---- metadata
ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_FILE}"
FILE_SIZE_BYTES="$(stat -c%s "${ARCHIVE_PATH}")"
FILE_SIZE_HUMAN="$(du -h "${ARCHIVE_PATH}" | cut -f1)"
END_TIME="$(date +%s)"
DURATION="$((END_TIME - START_TIME))"
DURATION_FMT="$(printf '%02d:%02d:%02d' $((DURATION/3600)) $((DURATION%3600/60)) $((DURATION%60)))"
MESSAGE=$(cat <<EOF
PostgreSQL backup completed

Host: ${HOSTNAME}
File: ${ARCHIVE_FILE}
Size: ${FILE_SIZE_HUMAN}
Duration: ${DURATION_FMT}
Timestamp: $(date -Is)
EOF
)

curl -s -X POST \
  'https://notify.leanderziehm.com/notify/me' \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg text "$MESSAGE" '{text: $text}')"

