#!/usr/bin/env bash
# =============================================================================
# Hospital Discharge Manager — hdm-database
# backup_restore.sh
# Backup y restore manual de la base de datos HDM
# Uso:
#   sudo bash backup_restore.sh backup           → genera backup timestamped
#   sudo bash backup_restore.sh restore <archivo> → restaura desde archivo
# =============================================================================
set -euo pipefail

DB_NAME="hdm_db"
DB_USER="hdm_user"
BACKUP_DIR="/opt/hdm/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

case "${1:-}" in
    backup)
        BACKUP_FILE="$BACKUP_DIR/hdm_backup_${DATE}.sql.gz"
        PGPASSWORD="${DB_PASS:-hdm_pass_2024}" \
            pg_dump -U "$DB_USER" -d "$DB_NAME" \
            --no-owner --no-acl --clean --if-exists \
            | gzip > "$BACKUP_FILE"
        echo "✓ Backup guardado en: $BACKUP_FILE"
        ls -lh "$BACKUP_FILE"
        ;;

    restore)
        RESTORE_FILE="${2:-}"
        if [ -z "$RESTORE_FILE" ] || [ ! -f "$RESTORE_FILE" ]; then
            echo "❌ Archivo de backup no encontrado: $RESTORE_FILE"
            exit 1
        fi
        echo "Restaurando desde: $RESTORE_FILE"
        if [[ "$RESTORE_FILE" == *.gz ]]; then
            gunzip -c "$RESTORE_FILE" | PGPASSWORD="${DB_PASS:-hdm_pass_2024}" \
                psql -U "$DB_USER" -d "$DB_NAME"
        else
            PGPASSWORD="${DB_PASS:-hdm_pass_2024}" \
                psql -U "$DB_USER" -d "$DB_NAME" -f "$RESTORE_FILE"
        fi
        echo "✓ Restore completado desde $RESTORE_FILE"
        ;;

    list)
        echo "Backups disponibles en $BACKUP_DIR:"
        ls -lht "$BACKUP_DIR"/*.sql.gz 2>/dev/null || echo "(ninguno)"
        ;;

    *)
        echo "Uso: $0 {backup|restore <archivo>|list}"
        exit 1
        ;;
esac
