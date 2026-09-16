#!/usr/bin/env bash
# =============================================================================
# Hospital Discharge Manager — hdm-database
# add_to_existing_postgres.sh
# Añade hdm_db al cluster PostgreSQL existente (compartido con FBS u otra app)
# Uso: sudo bash add_to_existing_postgres.sh
# REQUISITO: PostgreSQL 16 ya instalado en esta VM
# =============================================================================
set -euo pipefail

DB_NAME="hdm_db"
DB_USER="hdm_user"
DB_PASS="hdm_pass_2024"
SQL_DIR="/opt/hdm/database/sql"

echo "=== HDM — Añadir base de datos al cluster PostgreSQL existente ==="

# Verificar que PostgreSQL está corriendo
if ! systemctl is-active --quiet postgresql; then
    echo "❌ PostgreSQL no está activo. Arráncalo primero."
    exit 1
fi

# Crear usuario y base de datos si no existen
sudo -u postgres psql <<SQL
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
        CREATE ROLE $DB_USER LOGIN PASSWORD '$DB_PASS';
        RAISE NOTICE 'Usuario $DB_USER creado';
    ELSE
        RAISE NOTICE 'Usuario $DB_USER ya existe — omitido';
    END IF;
END
\$\$;

SELECT 'CREATE DATABASE $DB_NAME OWNER $DB_USER'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec
SQL

echo "✓ Base de datos $DB_NAME lista"

# Añadir línea a pg_hba.conf solo si no existe ya
PG_HBA="/etc/postgresql/16/main/pg_hba.conf"
if ! grep -q "$DB_NAME.*$DB_USER" "$PG_HBA"; then
    cat >> "$PG_HBA" <<EOF

# HDM — Hospital Discharge Manager
host    $DB_NAME    $DB_USER    10.0.0.0/24    scram-sha-256
host    $DB_NAME    $DB_USER    127.0.0.1/32   scram-sha-256
EOF
    systemctl reload postgresql
    echo "✓ pg_hba.conf actualizado y PostgreSQL recargado"
else
    echo "✓ pg_hba.conf ya tenía las entradas de HDM — omitido"
fi

# Cargar schema, catálogos, seed y funciones de demo
for f in "$SQL_DIR"/0{1,2,3,4}_*.sql; do
    echo "  → Ejecutando $(basename $f)"
    PGPASSWORD="$DB_PASS" psql -U "$DB_USER" -d "$DB_NAME" -f "$f"
done

echo ""
echo "=== hdm_db lista y cargada en el cluster PostgreSQL compartido ==="
echo "    Bases de datos activas en este servidor:"
sudo -u postgres psql -c "\l" | grep -E "Name|fbs_db|hdm_db" || true
