#!/bin/bash
# Backup Script for Open-Source Stack
# Creates compressed backup of all Docker volumes (data services)

set -euo pipefail

# Load environment so S3_BACKUP_BUCKET / AWS_REGION are available
if [ -f /home/ubuntu/app/docker-compose/.env ]; then
    set -a
    # shellcheck disable=SC1091
    . /home/ubuntu/app/docker-compose/.env
    set +a
fi

AWS_REGION="${AWS_REGION:-ap-southeast-1}"

BACKUP_DIR="/data/backups"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
STAGING_DIR="/tmp/pretamane-backup-$BACKUP_DATE"
BACKUP_FILE="$BACKUP_DIR/backup-$BACKUP_DATE.tar.gz"

echo "========================================"
echo "Starting Backup Process"
echo "========================================"
echo "Date: $(date)"
echo "Backup file: $BACKUP_FILE"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"
mkdir -p "$STAGING_DIR"

# ============================================================================
# Stop services for consistent backup
# ============================================================================

echo "[1/6] Stopping services for consistent backup..."
cd /home/ubuntu/app/docker-compose
docker-compose stop
echo "Services stopped"

# ============================================================================
# Collect Docker volume data into staging
# ============================================================================

echo "[2/6] Staging volume data..."
VOLUME_MAP=(
  "docker-compose_postgres-data:postgresql"
  "docker-compose_meilisearch-data:meilisearch"
  "docker-compose_minio-data:minio"
  "docker-compose_uploads-data:uploads"
  "docker-compose_processed-data:processed"
  "docker-compose_logs-data:logs"
  "docker-compose_prometheus-data:prometheus"
  "docker-compose_grafana-data:grafana"
  "docker-compose_loki-data:loki"
  "docker-compose_pgadmin-data:pgadmin"
  "docker-compose_alertmanager-data:alertmanager"
  "docker-compose_caddy-data:caddy-data"
  "docker-compose_caddy-config:caddy-config"
)

for entry in "${VOLUME_MAP[@]}"; do
  vol_name="${entry%%:*}"
  dir_name="${entry##*:}"
  # Resolve mountpoint
  if docker volume inspect "$vol_name" >/dev/null 2>&1; then
    mountpoint=$(docker volume inspect -f '{{ .Mountpoint }}' "$vol_name" 2>/dev/null || true)
    if [ -n "${mountpoint:-}" ] && [ -d "$mountpoint" ]; then
      echo "  - $vol_name -> $dir_name"
      mkdir -p "$STAGING_DIR/$dir_name"
      # Preserve ownership and permissions
      cp -a "$mountpoint/." "$STAGING_DIR/$dir_name/" 2>/dev/null || true
    else
      echo "  - $vol_name: mountpoint not found, skipping"
    fi
  else
    echo "  - $vol_name: volume not present, skipping"
  fi
done

# ============================================================================
# Create backup archive
# ============================================================================

echo "[3/6] Creating backup archive..."
tar -C "/tmp" -czf "$BACKUP_FILE" "$(basename "$STAGING_DIR")"
echo "Backup created: $BACKUP_FILE"
echo "Size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Cleanup staging
rm -rf "$STAGING_DIR"

# ============================================================================
# Restart services
# ============================================================================

echo "[4/6] Restarting services..."
cd /home/ubuntu/app/docker-compose
docker-compose start
echo "Services restarted"

# ============================================================================
# Verify backup
# ============================================================================

echo "[5/6] Verifying backup..."
if [ -f "$BACKUP_FILE" ]; then
    echo "Backup file exists: ✓"
    echo "Size: $(du -h "$BACKUP_FILE" | cut -f1)"
    if tar -tzf "$BACKUP_FILE" > /dev/null 2>&1; then
        echo "Archive integrity: ✓"
    else
        echo "Archive integrity: ✗ FAILED"
        exit 1
    fi
else
    echo "Backup file not found: ✗ FAILED"
    exit 1
fi

# ============================================================================
# Optional: Upload to S3
# ============================================================================

if [ -n "${S3_BACKUP_BUCKET:-}" ]; then
    echo ""
    echo "[6/6] Uploading to S3 (bucket=$S3_BACKUP_BUCKET, region=$AWS_REGION)..."
    aws s3 cp "$BACKUP_FILE" "s3://$S3_BACKUP_BUCKET/backups/" --region "$AWS_REGION" || echo "S3 upload failed (non-critical)"
fi

echo ""
echo "========================================"
echo "Backup Complete!"
echo "========================================"
echo "Backup file: $BACKUP_FILE"
echo "Size: $(du -h "$BACKUP_FILE" | cut -f1)"
echo "Log location: /var/log/pretamane-backup.log (if run via cron)"
echo "========================================"




