-- =============================================================================
-- Hospital Discharge Manager (HDM)
-- Scripts de demo: 04_demo_scripts.sql
-- Estos scripts son invocados por el Backend Demo Engine
-- =============================================================================

-- -----------------------------------------------------------------------------
-- DEMO: Human Error
-- Simula borrado accidental de la tabla discharges
-- El backend llama a esto via /api/demo/human-error
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION demo_human_error()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    -- Registrar el evento ANTES de borrar
    INSERT INTO system_events (event_type, severity, message, metadata)
    VALUES (
        'demo_human_error', 'critical',
        '¡ERROR! Tabla discharges borrada accidentalmente por operador',
        jsonb_build_object(
            'rows_deleted', (SELECT COUNT(*) FROM discharges),
            'triggered_at', NOW()
        )
    );

    -- El borrado simulado: truncate completo
    TRUNCATE TABLE discharges RESTART IDENTITY;

    -- También borrar snapshots para que los KPIs queden a 0
    TRUNCATE TABLE kpi_snapshots;

    RAISE NOTICE 'DEMO human_error ejecutado: tabla discharges vaciada';
END;
$$;

-- -----------------------------------------------------------------------------
-- DEMO: Ransomware (Wario)
-- Corrompe los datos de discharges (actualiza con basura)
-- El backend llama a esto via /api/demo/ransomware
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION demo_ransomware()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO system_events (event_type, severity, message, metadata)
    VALUES (
        'demo_ransomware', 'critical',
        'RANSOMWARE DETECTADO: datos de discharges cifrados por agente malicioso (Wario)',
        jsonb_build_object(
            'rows_affected', (SELECT COUNT(*) FROM discharges),
            'triggered_at', NOW(),
            'attacker', 'Wario'
        )
    );

    -- Corrupción simulada: sobreescribir campos con datos ininteligibles
    UPDATE discharges SET
        patient_name    = '█████████████',
        ward            = '???',
        diagnosis_code  = 'ENCRYPTED',
        diagnosis_description = repeat('X', 50),
        notes           = 'FILES ENCRYPTED BY WARIO RANSOMWARE v2.0 — PAY NOW',
        status          = 'error';

    RAISE NOTICE 'DEMO ransomware ejecutado: datos corrompidos';
END;
$$;

-- -----------------------------------------------------------------------------
-- DEMO: Recovery
-- Restaura el estado de la base de datos tras un demo de error
-- Llamado automáticamente por el backend tras el failover/journal recovery
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION demo_recovery(p_demo_type TEXT DEFAULT 'unknown')
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_count INTEGER;
BEGIN
    INSERT INTO system_events (event_type, severity, message, metadata)
    VALUES (
        'demo_recovery', 'info',
        'Recovery completado via Zerto Journal. Datos restaurados al punto anterior al incidente.',
        jsonb_build_object(
            'demo_type', p_demo_type,
            'recovery_point', NOW() - INTERVAL '2 minutes',
            'triggered_at', NOW()
        )
    );

    SELECT COUNT(*) INTO v_count FROM discharges;
    RAISE NOTICE 'DEMO recovery: % filas disponibles tras restauración', v_count;
END;
$$;

-- -----------------------------------------------------------------------------
-- FUNCIÓN: Insertar una alta (usada por el RBG del backend)
-- El backend llama a esta función para cada alta generada aleatoriamente
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION insert_discharge(
    p_patient_id          VARCHAR(12),
    p_patient_name        VARCHAR(120),
    p_ward                VARCHAR(80),
    p_bed_number          VARCHAR(10),
    p_admission_date      DATE,
    p_discharge_type      VARCHAR(40),
    p_diagnosis_code      VARCHAR(12),
    p_diagnosis_desc      VARCHAR(200),
    p_attending_unit      VARCHAR(80),
    p_destination         VARCHAR(80),
    p_processing_time_min INTEGER
)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
    v_id INTEGER;
BEGIN
    INSERT INTO discharges (
        patient_id, patient_name, ward, bed_number,
        admission_date, discharge_date, discharge_type,
        diagnosis_code, diagnosis_description,
        attending_unit, destination,
        processing_time_min, status
    ) VALUES (
        p_patient_id, p_patient_name, p_ward, p_bed_number,
        p_admission_date, NOW(), p_discharge_type,
        p_diagnosis_code, p_diagnosis_desc,
        p_attending_unit, p_destination,
        p_processing_time_min, 'completed'
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- FUNCIÓN: Snapshot periódico de KPIs
-- Llamada cada 5 min por el backend para construir gráficas históricas
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION snapshot_kpis()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO kpi_snapshots (
        total_discharges, discharges_last_hour,
        avg_processing_time_min, beds_freed_today,
        patients_pending, occupancy_pct
    )
    SELECT
        total_discharges,
        discharges_last_hour,
        avg_processing_time_min,
        beds_freed_today,
        patients_pending,
        -- Ocupación simplificada: inverso del ratio pendientes/total_camas
        GREATEST(0, LEAST(100, 85.0 - (patients_pending * 2.0)))
    FROM v_kpis_live;
END;
$$;
