-- =============================================================================
-- Hospital Discharge Manager (HDM)
-- Schema: 01_schema.sql
-- PostgreSQL 16
-- =============================================================================

-- Extensiones
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- =============================================================================
-- TABLA PRINCIPAL: discharges
-- Registro de altas médicas procesadas o en tramitación
-- =============================================================================
CREATE TABLE IF NOT EXISTS discharges (
    id                    SERIAL PRIMARY KEY,
    patient_id            VARCHAR(12)  NOT NULL,          -- Formato: P-XXXXXXX
    patient_name          VARCHAR(120) NOT NULL,
    ward                  VARCHAR(80)  NOT NULL,           -- Ej: "Cardiología · 3ª planta"
    bed_number            VARCHAR(10)  NOT NULL,           -- Ej: "302-B"
    admission_date        DATE         NOT NULL,
    discharge_date        TIMESTAMP    NOT NULL DEFAULT NOW(),
    discharge_type        VARCHAR(40)  NOT NULL,           -- Ver tabla discharge_types
    diagnosis_code        VARCHAR(12)  NOT NULL,           -- CIE-10 simplificado
    diagnosis_description VARCHAR(200),
    attending_unit        VARCHAR(80)  NOT NULL,           -- Servicio responsable
    destination           VARCHAR(80),                     -- Domicilio / Residencia / Traslado hospital
    processing_time_min   INTEGER      NOT NULL CHECK (processing_time_min >= 0),
    notes                 TEXT,
    status                VARCHAR(20)  NOT NULL DEFAULT 'completed'
                          CHECK (status IN ('pending', 'completed', 'error', 'cancelled')),
    created_at            TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- TABLA: wards
-- Catálogo de plantas/unidades del hospital
-- =============================================================================
CREATE TABLE IF NOT EXISTS wards (
    id            SERIAL PRIMARY KEY,
    code          VARCHAR(20) UNIQUE NOT NULL,
    name          VARCHAR(80) NOT NULL,
    floor         INTEGER NOT NULL,
    specialty     VARCHAR(60) NOT NULL,
    total_beds    INTEGER NOT NULL CHECK (total_beds > 0),
    active        BOOLEAN NOT NULL DEFAULT TRUE
);

-- =============================================================================
-- TABLA: discharge_types
-- Catálogo de tipos de alta
-- =============================================================================
CREATE TABLE IF NOT EXISTS discharge_types (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(20) UNIQUE NOT NULL,
    description VARCHAR(80) NOT NULL,
    active      BOOLEAN NOT NULL DEFAULT TRUE
);

-- =============================================================================
-- TABLA: system_events
-- Registro de eventos del sistema (para la Observability Console)
-- Incluye: arranque del RBG, errores, demos ejecutadas
-- =============================================================================
CREATE TABLE IF NOT EXISTS system_events (
    id          SERIAL PRIMARY KEY,
    event_type  VARCHAR(40) NOT NULL,   -- 'rbg_start','rbg_stop','demo_failover',
                                         -- 'demo_human_error','demo_ransomware','error'
    severity    VARCHAR(10) NOT NULL DEFAULT 'info'
                CHECK (severity IN ('info', 'warning', 'error', 'critical')),
    message     TEXT NOT NULL,
    metadata    JSONB,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- TABLA: kpi_snapshots
-- Snapshots periódicos de KPIs para gráficas históricas en la consola
-- =============================================================================
CREATE TABLE IF NOT EXISTS kpi_snapshots (
    id                       SERIAL PRIMARY KEY,
    snapshot_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    total_discharges         INTEGER   NOT NULL DEFAULT 0,
    discharges_last_hour     INTEGER   NOT NULL DEFAULT 0,
    avg_processing_time_min  NUMERIC(6,2),
    beds_freed_today         INTEGER   NOT NULL DEFAULT 0,
    patients_pending         INTEGER   NOT NULL DEFAULT 0,
    occupancy_pct            NUMERIC(5,2)    -- % global del hospital
);

-- =============================================================================
-- ÍNDICES
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_discharges_status         ON discharges(status);
CREATE INDEX IF NOT EXISTS idx_discharges_discharge_date ON discharges(discharge_date DESC);
CREATE INDEX IF NOT EXISTS idx_discharges_ward           ON discharges(ward);
CREATE INDEX IF NOT EXISTS idx_discharges_patient_id     ON discharges(patient_id);
CREATE INDEX IF NOT EXISTS idx_system_events_type        ON system_events(event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_kpi_snapshots_at          ON kpi_snapshots(snapshot_at DESC);

-- =============================================================================
-- FUNCIÓN: updated_at automático
-- =============================================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_discharges_updated_at
    BEFORE UPDATE ON discharges
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- VISTA: v_ward_occupancy
-- Ocupación actual por planta (usada por el backend para el KPI de ocupación)
-- =============================================================================
CREATE OR REPLACE VIEW v_ward_occupancy AS
SELECT
    w.code,
    w.name                                          AS ward_name,
    w.specialty,
    w.floor,
    w.total_beds,
    COUNT(d.id) FILTER (
        WHERE d.status = 'pending'
        AND d.discharge_date::date = CURRENT_DATE
    )                                               AS pending_today,
    COUNT(d.id) FILTER (
        WHERE d.discharge_date::date = CURRENT_DATE
        AND d.status = 'completed'
    )                                               AS freed_today,
    ROUND(
        (w.total_beds - COUNT(d.id) FILTER (
            WHERE d.status = 'pending'
        ))::numeric / w.total_beds * 100, 1
    )                                               AS occupancy_pct
FROM wards w
LEFT JOIN discharges d ON d.ward = w.name
WHERE w.active = TRUE
GROUP BY w.id, w.code, w.name, w.specialty, w.floor, w.total_beds
ORDER BY w.floor, w.name;

-- =============================================================================
-- VISTA: v_kpis_live
-- KPIs en tiempo real para el endpoint /api/kpis del backend
-- =============================================================================
CREATE OR REPLACE VIEW v_kpis_live AS
SELECT
    COUNT(*)                                                        AS total_discharges,
    COUNT(*) FILTER (
        WHERE discharge_date >= NOW() - INTERVAL '1 hour'
    )                                                               AS discharges_last_hour,
    ROUND(AVG(processing_time_min)::numeric, 1)                    AS avg_processing_time_min,
    COUNT(*) FILTER (
        WHERE discharge_date::date = CURRENT_DATE
        AND status = 'completed'
    )                                                               AS beds_freed_today,
    COUNT(*) FILTER (WHERE status = 'pending')                      AS patients_pending,
    COUNT(*) FILTER (
        WHERE discharge_date >= NOW() - INTERVAL '24 hours'
    )                                                               AS discharges_last_24h
FROM discharges;
