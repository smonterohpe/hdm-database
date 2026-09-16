-- =============================================================================
-- Hospital Discharge Manager (HDM)
-- Seed de datos: 03_seed.sql
-- 120 altas ficticias distribuidas en los últimos 7 días
-- =============================================================================

-- Función temporal para generar altas con fechas aleatorias
DO $$
DECLARE
    wards_list    TEXT[]    := ARRAY[
        'Cardiología · 3ª planta',
        'Neurología · 4ª planta',
        'Traumatología · 2ª planta',
        'Cirugía General · 5ª planta',
        'Medicina Interna · 1ª planta',
        'Oncología · 6ª planta',
        'Geriatría · Planta baja'
    ];
    dtypes        TEXT[]    := ARRAY[
        'DOMICILIO','DOMICILIO','DOMICILIO',   -- Alta probabilidad domicilio
        'RESIDENCIA','TRASLADO',
        'VOLUNTARIA','HOSPITALIZACION_DIA'
    ];
    diag_codes    TEXT[]    := ARRAY[
        'I21','I50','I10','I48',     -- Cardio
        'G45','G35','G20','I63',     -- Neuro
        'S72','S82','M17','M54',     -- Trauma
        'K40','K80','K57','K92',     -- Cirugía
        'J18','J44','E11','N39',     -- Med Interna
        'C34','C50','C61','C18',     -- Onco
        'I69','E78','M81','F00'      -- Geriatría
    ];
    diag_descs    TEXT[]    := ARRAY[
        'Infarto agudo de miocardio', 'Insuficiencia cardíaca', 'Hipertensión esencial',
        'Fibrilación auricular', 'Accidente isquémico transitorio', 'Esclerosis múltiple',
        'Enfermedad de Parkinson', 'Infarto cerebral', 'Fractura de cadera',
        'Fractura de tibia/peroné', 'Artrosis de rodilla', 'Dorsalgia',
        'Hernia inguinal', 'Colelitiasis', 'Enfermedad diverticular',
        'Hemorragia gastrointestinal', 'Neumonía', 'EPOC agudizada',
        'Diabetes tipo 2', 'Infección urinaria', 'Neoplasia pulmón',
        'Neoplasia mama', 'Neoplasia próstata', 'Neoplasia colon',
        'Secuelas ACV', 'Dislipemia', 'Osteoporosis', 'Demencia'
    ];
    attending_units TEXT[] := ARRAY[
        'Dr. García Martínez', 'Dra. López Sánchez', 'Dr. Fernández Ruiz',
        'Dra. Martínez Gómez', 'Dr. Sánchez Torres', 'Dra. Romero Díaz',
        'Dr. Navarro Jiménez', 'Dra. Moreno Castro'
    ];
    destinations  TEXT[]   := ARRAY[
        'Domicilio familiar', 'Domicilio propio', 'Residencia El Pinar',
        'Residencia Los Olivos', 'Hospital Regional de Referencia',
        'Centro de Salud Alta Gracia', 'Unidad de Rehabilitación'
    ];
    first_names   TEXT[]   := ARRAY[
        'Manuel','María','José','Carmen','Antonio','Josefa','Francisco','Ana',
        'Juan','Isabel','Luis','Pilar','Miguel','Dolores','Carlos','Concepción',
        'Jesús','Rosario','Ángel','Francisca','Alejandro','Elena','David','Teresa',
        'Daniel','Mercedes','Pablo','Encarnación','Pedro','Cristina'
    ];
    last_names    TEXT[]   := ARRAY[
        'García','González','Rodríguez','Fernández','López','Martínez','Sánchez',
        'Pérez','Gómez','Martín','Jiménez','Ruiz','Hernández','Díaz','Moreno',
        'Álvarez','Muñoz','Romero','Alonso','Gutiérrez','Navarro','Torres',
        'Domínguez','Vázquez','Ramos','Gil','Serrano','Blanco','Molina','Morales'
    ];
    i             INTEGER;
    ward_idx      INTEGER;
    discharge_ts  TIMESTAMP;
    proc_time     INTEGER;
    patient_name  TEXT;
    patient_id    TEXT;
    bed_num       TEXT;
    diag_idx      INTEGER;
BEGIN
    FOR i IN 1..120 LOOP
        -- Distribución de fechas: últimos 7 días, más carga en días recientes
        discharge_ts := NOW() - (random() * INTERVAL '7 days')
                        + (random() * INTERVAL '16 hours') -- horario laboral simulado
                        - INTERVAL '8 hours';

        ward_idx    := (floor(random() * 7) + 1)::INTEGER;
        proc_time   := (floor(random() * 55) + 5)::INTEGER;  -- 5-60 min
        patient_name := first_names[ceil(random()*30)::INT]
                        || ' ' || last_names[ceil(random()*30)::INT]
                        || ' ' || last_names[ceil(random()*30)::INT];
        patient_id  := 'P-' || LPAD((floor(random()*9000000)+1000000)::TEXT, 7, '0');
        bed_num     := (floor(random()*4)+1)::TEXT
                        || (floor(random()*30)+100)::TEXT
                        || '-' || chr(65 + floor(random()*4)::INT);   -- A-D
        diag_idx    := (floor(random() * array_length(diag_codes, 1)) + 1)::INTEGER;

        INSERT INTO discharges (
            patient_id, patient_name, ward, bed_number,
            admission_date, discharge_date, discharge_type,
            diagnosis_code, diagnosis_description,
            attending_unit, destination,
            processing_time_min, status
        ) VALUES (
            patient_id,
            patient_name,
            wards_list[ward_idx],
            bed_num,
            (discharge_ts - (floor(random()*14)+1 || ' days')::INTERVAL)::DATE,
            discharge_ts,
            dtypes[ceil(random()*7)::INT],
            diag_codes[diag_idx],
            diag_descs[diag_idx % array_length(diag_descs,1) + 1],
            attending_units[ceil(random()*8)::INT],
            destinations[ceil(random()*7)::INT],
            proc_time,
            'completed'
        );
    END LOOP;

    -- Añadir 5 altas pendientes (para el KPI de pacientes en espera)
    FOR i IN 1..5 LOOP
        ward_idx := (floor(random() * 7) + 1)::INTEGER;
        patient_name := first_names[ceil(random()*30)::INT]
                        || ' ' || last_names[ceil(random()*30)::INT]
                        || ' ' || last_names[ceil(random()*30)::INT];
        patient_id := 'P-' || LPAD((floor(random()*9000000)+1000000)::TEXT, 7, '0');
        diag_idx   := (floor(random() * array_length(diag_codes, 1)) + 1)::INTEGER;

        INSERT INTO discharges (
            patient_id, patient_name, ward, bed_number,
            admission_date, discharge_date, discharge_type,
            diagnosis_code, diagnosis_description,
            attending_unit, processing_time_min, status
        ) VALUES (
            patient_id,
            patient_name,
            wards_list[ward_idx],
            (floor(random()*4)+1)::TEXT || (floor(random()*30)+100)::TEXT || '-A',
            (NOW() - (floor(random()*5)+1 || ' days')::INTERVAL)::DATE,
            NOW(),
            dtypes[ceil(random()*7)::INT],
            diag_codes[diag_idx],
            diag_descs[diag_idx % array_length(diag_descs,1) + 1],
            attending_units[ceil(random()*8)::INT],
            (floor(random()*30)+5)::INTEGER,
            'pending'
        );
    END LOOP;

    -- Evento de arranque del sistema
    INSERT INTO system_events (event_type, severity, message, metadata)
    VALUES ('system_init', 'info', 'Base de datos HDM inicializada correctamente',
            '{"version": "1.0.0", "seed_records": 125}'::jsonb);

    RAISE NOTICE 'Seed completado: 120 altas completadas + 5 pendientes';
END;
$$;

-- Snapshot KPI inicial
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
    -- Ocupación estimada ficticia al arranque
    72.5
FROM v_kpis_live;
