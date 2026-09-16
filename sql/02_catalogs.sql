-- =============================================================================
-- Hospital Discharge Manager (HDM)
-- Catálogos: 02_catalogs.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Tipos de alta
-- -----------------------------------------------------------------------------
INSERT INTO discharge_types (code, description) VALUES
    ('DOMICILIO',    'Alta a domicilio'),
    ('RESIDENCIA',   'Traslado a residencia sociosanitaria'),
    ('TRASLADO',     'Traslado a otro centro hospitalario'),
    ('VOLUNTARIA',   'Alta voluntaria'),
    ('EXITUS',       'Exitus letalis'),
    ('HOSPITALIZACION_DIA', 'Hospitalización de día finalizada')
ON CONFLICT (code) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Plantas / unidades del hospital
-- Hospital Universitario Demo — 200 camas ficticias
-- -----------------------------------------------------------------------------
INSERT INTO wards (code, name, floor, specialty, total_beds) VALUES
    ('CARD-3',  'Cardiología · 3ª planta',          3, 'Cardiología',         28),
    ('NEUR-4',  'Neurología · 4ª planta',            4, 'Neurología',          24),
    ('TRAU-2',  'Traumatología · 2ª planta',         2, 'Traumatología',       32),
    ('CIR-5',   'Cirugía General · 5ª planta',       5, 'Cirugía General',     30),
    ('MED-INT', 'Medicina Interna · 1ª planta',      1, 'Medicina Interna',    36),
    ('ONCO-6',  'Oncología · 6ª planta',             6, 'Oncología',           20),
    ('GERIAT',  'Geriatría · Planta baja',           0, 'Geriatría',           30)
ON CONFLICT (code) DO NOTHING;
