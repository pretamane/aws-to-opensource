#!/bin/bash
# Backup Script for Open-Source Stack
# Creates compressed backup of all data directories

set -e

BACKUP_DIR="/data/backups"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup-$BACKUP_DATE.tar.gz"

echo "========================================"
echo "Starting Backup Process"
echo "========================================"
echo "Date: $(date)"
echo "Backup file: $BACKUP_FILE"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# ============================================================================
# Stop services for consistent backup
# ============================================================================

echo "[1/5] Stopping services for consistent backup..."
cd /home/ubuntu/app/docker-compose
docker-compose stop

echo "Services stopped"

# ============================================================================
# Create backup
# ============================================================================

echo "[2/5] Creating backup archive..."
cd /data

tar -czf "$BACKUP_FILE" \
    --exclude='backups' \
    postgresql/ \
    meilisearch/ \
    minio/ \
    uploads/ \
    processed/ \
    logs/ \
    prometheus/ \
    grafana/ \
    loki/ \
    2>/dev/null || true

echo "Backup created: $BACKUP_FILE"
echo "Size: $(du -h $BACKUP_FILE | cut -f1)"

# ============================================================================
# Restart services
# ============================================================================

echo "[3/5] Restarting services..."
cd /home/ubuntu/app/docker-compose
docker-compose start

echo "Services restarted"

# ============================================================================
# Verify backup
# ============================================================================

echo "[4/5] Verifying backup..."
if [ -f "$BACKUP_FILE" ]; then
    echo "Backup file exists: ✓"
    echo "Size: $(du -h $BACKUP_FILE | cut -f1)"
    
    # Test archive integrity
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
# Clean old backups (keep last 7 days)
# ============================================================================

echo "[5/5] Cleaning old backups (keeping last 7 days)..."
find "$BACKUP_DIR" -name "backup-*.tar.gz" -mtime +7 -delete
echo "Old backups cleaned"

# List remaining backups
echo ""
echo "Available backups:"
ls -lh "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null || echo "No backups found"

# ============================================================================
# Optional: Upload to S3
# ============================================================================

if [ ! -z "$S3_BACKUP_BUCKET" ]; then
    echo ""
    echo "Uploading to S3..."
    aws s3 cp "$BACKUP_FILE" "s3://$S3_BACKUP_BUCKET/backups/" || echo "S3 upload failed (non-critical)"
fi

echo ""
echo "========================================"
echo "Backup Complete!"
echo "========================================"
echo "Backup file: $BACKUP_FILE"
echo "Size: $(du -h $BACKUP_FILE | cut -f1)"
echo ""
echo "To restore:"
echo "  ./scripts/restore-data.sh $BACKUP_FILE"
echo ""
echo "To download:"
echo "  scp ubuntu@<ec2-ip>:$BACKUP_FILE ./"
echo ""
echo "========================================"


