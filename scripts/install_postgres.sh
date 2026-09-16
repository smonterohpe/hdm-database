#!/usr/bin/env bash
# =============================================================================
# Hospital Discharge Manager — hdm-database
# install_postgres.sh
# Instala y configura PostgreSQL 16 en Ubuntu 24.04 (VM bare-metal)
# Uso: sudo bash install_postgres.sh
# =============================================================================
set -euo pipefail

DB_NAME="hdm_db"
DB_USER="hdm_user"
DB_PASS="hdm_pass_2024"     # Cambiar en producción
SQL_DIR="/opt/hdm/database/sql"

echo "=============================================="
echo " HDM — Instalación PostgreSQL 16"
echo "=============================================="

# 1. Repositorio oficial de PostgreSQL
apt-get update -qq
apt-get install -y curl gnupg lsb-release

curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg

echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] \
    https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list

apt-get update -qq
apt-get install -y postgresql-16 postgresql-client-16

echo "✓ PostgreSQL 16 instalado"

# 2. Configurar pg_hba.conf para aceptar conexiones desde la red interna
PG_HBA="/etc/postgresql/16/main/pg_hba.conf"
PG_CONF="/etc/postgresql/16/main/postgresql.conf"

# Escuchar en todas las interfaces (el firewall de la VM restringe el acceso)
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"

# Permitir conexión del backend (ajustar IP de la VM backend)
cat >> "$PG_HBA" <<EOF

# HDM — Backend VM
host    $DB_NAME    $DB_USER    10.0.0.0/24    scram-sha-256
host    $DB_NAME    $DB_USER    127.0.0.1/32   scram-sha-256
EOF

echo "✓ pg_hba.conf y postgresql.conf actualizados"

# 3. Crear usuario y base de datos
systemctl start postgresql
systemctl enable postgresql

sudo -u postgres psql <<SQL
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
        CREATE ROLE $DB_USER LOGIN PASSWORD '$DB_PASS';
    END IF;
END
\$\$;

SELECT 'CREATE DATABASE $DB_NAME OWNER $DB_USER'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec
SQL

echo "✓ Usuario $DB_USER y base de datos $DB_NAME creados"

# 4. Cargar schema, catálogos y seed
if [ -d "$SQL_DIR" ]; then
    sudo -u postgres psql -d "$DB_NAME" \
        -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"

    for f in "$SQL_DIR"/0{1,2,3,4}_*.sql; do
        echo "  → Ejecutando $f"
        PGPASSWORD="$DB_PASS" psql -U "$DB_USER" -d "$DB_NAME" -f "$f"
    done
    echo "✓ Schema y datos cargados"
else
    echo "⚠  Directorio SQL no encontrado en $SQL_DIR — ejecuta los scripts manualmente"
fi

# 5. Reiniciar para aplicar configuración
systemctl restart postgresql

echo "=============================================="
echo " Instalación completada."
echo " Host:     localhost:5432"
echo " Base de datos: $DB_NAME"
echo " Usuario:  $DB_USER"
echo " Contraseña: [definida en DB_PASS]"
echo "=============================================="
