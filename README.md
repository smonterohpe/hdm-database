# hdm-database

**Hospital Discharge Manager (HDM)** · Componente de base de datos  
PostgreSQL 16 · VM Ubuntu 24.04 · Puerto 5432

---

## Descripción

Capa de persistencia del simulador HDM para demos de continuidad de negocio con Zerto.  
Almacena las altas médicas generadas por el RBG (Random Booking Generator) del backend y expone vistas y funciones SQL para los KPIs de la Observability Console.

---

## Estructura del repositorio

```
hdm-database/
├── sql/
│   ├── 00_init.sql          ← Init maestro (llama al resto en orden)
│   ├── 01_schema.sql        ← Tablas, índices, triggers, vistas
│   ├── 02_catalogs.sql      ← Catálogo de plantas y tipos de alta
│   ├── 03_seed.sql          ← 120 altas históricas ficticias
│   └── 04_demo_scripts.sql  ← Funciones de demo (human error, ransomware, recovery)
├── scripts/
│   ├── install_postgres.sh  ← Instalación en VM bare-metal Ubuntu 24.04
│   └── backup_restore.sh    ← Backup/restore manual
├── docker/
│   └── docker-compose.yml   ← Entorno de desarrollo local
└── README.md
```

---

## Arranque rápido (desarrollo local con Docker)

```bash
cd docker
docker compose up -d
# La primera vez ejecuta automáticamente sql/0{1..4}_*.sql
```

Comprobar que está listo:
```bash
docker exec -it hdm-database psql -U hdm_user -d hdm_db -c "SELECT * FROM v_kpis_live;"
```

---

## Instalación en VM Ubuntu 24.04 (producción)

```bash
# Clonar el repo en la VM
git clone https://github.com/smonterohpe/hdm-database.git /opt/hdm/database

# Instalar PostgreSQL 16 y cargar el schema
sudo bash /opt/hdm/database/scripts/install_postgres.sh
```

---

## Tablas principales

| Tabla | Descripción |
|---|---|
| `discharges` | Altas médicas (tabla principal) |
| `wards` | Plantas y unidades del hospital |
| `discharge_types` | Catálogo de tipos de alta |
| `system_events` | Log de eventos del sistema |
| `kpi_snapshots` | Histórico de KPIs (cada 5 min) |

## Vistas

| Vista | Uso |
|---|---|
| `v_kpis_live` | KPIs en tiempo real → endpoint `/api/kpis` del backend |
| `v_ward_occupancy` | Ocupación por planta → endpoint `/api/wards` |

## Funciones de demo

| Función | Escenario |
|---|---|
| `demo_human_error()` | Borra la tabla `discharges` (simula error operador) |
| `demo_ransomware()` | Corrompe los datos (simula Wario ransomware) |
| `demo_recovery(tipo)` | Registra el recovery tras restauración Zerto |
| `insert_discharge(...)` | Inserta un alta (llamada por el RBG del backend) |
| `snapshot_kpis()` | Guarda snapshot periódico de KPIs |

---

## Credenciales (desarrollo)

| Parámetro | Valor |
|---|---|
| Host | `localhost` / IP de VM3 |
| Puerto | `5432` |
| Base de datos | `hdm_db` |
| Usuario | `hdm_user` |
| Contraseña | `hdm_pass_2024` ← **Cambiar en producción** |

---

## Repositorios del proyecto HDM

| Repo | Descripción |
|---|---|
| [hdm-database](https://github.com/smonterohpe/hdm-database) | **Este repo** · PostgreSQL 16 |
| [hdm-backend](https://github.com/smonterohpe/hdm-backend) | FastAPI + Gunicorn + RBG |
| [hdm-frontend](https://github.com/smonterohpe/hdm-frontend) | nginx · UI de altas médicas |
| [hdm-observability](https://github.com/smonterohpe/hdm-observability) | Console · KPIs · Zerto |
