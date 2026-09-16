-- =============================================================================
-- Hospital Discharge Manager (HDM)
-- Init maestro: 00_init.sql
-- Ejecutar como: psql -U hdm_user -d hdm_db -f /docker-entrypoint-initdb.d/00_init.sql
-- =============================================================================

\echo '======================================================'
\echo ' HDM — Hospital Discharge Manager'
\echo ' Inicializando base de datos...'
\echo '======================================================'

\i /docker-entrypoint-initdb.d/01_schema.sql
\echo '✓ Schema creado'

\i /docker-entrypoint-initdb.d/02_catalogs.sql
\echo '✓ Catálogos insertados'

\i /docker-entrypoint-initdb.d/03_seed.sql
\echo '✓ Seed de datos cargado'

\i /docker-entrypoint-initdb.d/04_demo_scripts.sql
\echo '✓ Funciones de demo registradas'

\echo '======================================================'
\echo ' Base de datos lista.'
\echo '======================================================'
