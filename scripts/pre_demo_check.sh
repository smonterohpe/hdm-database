#!/bin/bash
# =============================================================================
# pre_demo_check.sh — Verifica que el entorno HDM está listo para la demo
#
# Ejecutar en VM3 (database) antes de empezar.
# =============================================================================

PGDATA="/var/lib/postgresql/16/main"
BACKUP_DIR="$(dirname "$0")/backup"
BACKEND_HOST="10.10.44.14"
FRONTEND_HOST="10.10.44.13"
BACKEND_PORT="8001"
FRONTEND_PORT="8081"

GRN='\033[0;32m'; RED='\033[0;31m'; YEL='\033[1;33m'; BLD='\033[1m'; RST='\033[0m'
PASS=0; FAIL=0; WARN=0

ok()   { echo -e "  ${GRN}✔${RST}  $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}✗${RST}  $1"; FAIL=$((FAIL+1)); }
warn() { echo -e "  ${YEL}⚠${RST}  $1"; WARN=$((WARN+1)); }

echo -e "\n${BLD}═══ PRE-DEMO CHECK — HOSPITAL DISCHARGE MANAGER ════${RST}\n"

# ── Base de datos ─────────────────────────────────────────────────────────────
echo -e "${BLD}[Base de datos]${RST}"

systemctl is-active postgresql > /dev/null 2>&1 \
  && ok "PostgreSQL activo" || fail "PostgreSQL NO está activo"

[ -d "$PGDATA" ] \
  && ok "PGDATA existe: $PGDATA" || fail "No se encuentra PGDATA"

PGPASSWORD=hdm_pass_2024 psql -h localhost -U hdm_user -d hdm_db \
  -c 'SELECT 1;' -q -t > /dev/null 2>&1 \
  && ok "Base de datos 'hdm_db' responde" \
  || fail "No se puede conectar a 'hdm_db'"

DISCHARGES=$(PGPASSWORD=hdm_pass_2024 psql -h localhost -U hdm_user -d hdm_db \
  -c 'SELECT COUNT(*) FROM discharges;' -q -t 2>/dev/null | tr -d ' ')
[ -n "$DISCHARGES" ] \
  && ok "Altas en BD: $DISCHARGES" \
  || warn "No se pudo contar altas"

[ ! -d "$BACKUP_DIR" ] \
  && ok "Sin backup previo (entorno limpio)" \
  || warn "Ya existe backup en $BACKUP_DIR — ¿hay una demo sin restaurar?"

FREE_GB=$(df -BG "$PGDATA" | awk 'NR==2{gsub("G","",$4); print $4}')
[ "$FREE_GB" -ge 5 ] \
  && ok "Espacio libre: ${FREE_GB} GB (suficiente para el ataque)" \
  || fail "Espacio libre insuficiente: ${FREE_GB} GB (necesitas al menos 5 GB)"

openssl version > /dev/null 2>&1 \
  && ok "openssl instalado" || fail "openssl NO instalado (apt install openssl)"

# ── Backend ───────────────────────────────────────────────────────────────────
echo -e "\n${BLD}[Backend HDM]${RST}"

HEALTH=$(curl -s --max-time 5 "http://$BACKEND_HOST:$BACKEND_PORT/api/health" 2>/dev/null)
echo "$HEALTH" | grep -q '"status":"ok"' \
  && ok "Backend responde (health OK)" \
  || fail "Backend no responde en $BACKEND_HOST:$BACKEND_PORT"

RBG=$(curl -s --max-time 5 "http://$BACKEND_HOST:$BACKEND_PORT/api/health" 2>/dev/null)
echo "$RBG" | grep -q '"running":true' \
  && ok "RBG activo (generando altas)" \
  || warn "RBG no está activo — verifica el backend"

TOTAL_DB=$(curl -s --max-time 5 "http://$BACKEND_HOST:$BACKEND_PORT/api/kpis" 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('total_discharges','?'))" 2>/dev/null)
[ -n "$TOTAL_DB" ] && [ "$TOTAL_DB" != "?" ] \
  && ok "KPIs accesibles — total altas: $TOTAL_DB" \
  || warn "No se pudieron obtener KPIs del backend"

# ── Frontend ──────────────────────────────────────────────────────────────────
echo -e "\n${BLD}[Frontend HDM]${RST}"

curl -s --max-time 5 "http://$FRONTEND_HOST:$FRONTEND_PORT/" > /dev/null 2>&1 \
  && ok "Frontend accesible en $FRONTEND_HOST:$FRONTEND_PORT" \
  || fail "Frontend no responde"

# ── Scripts de demo ───────────────────────────────────────────────────────────
echo -e "\n${BLD}[Scripts de demo]${RST}"

[ -x "$(dirname "$0")/encrypt_postgres.sh" ] \
  && ok "encrypt_postgres.sh listo" \
  || fail "encrypt_postgres.sh no encontrado o sin permisos de ejecución"

[ -x "$(dirname "$0")/restore_postgres.sh" ] \
  && ok "restore_postgres.sh listo" \
  || fail "restore_postgres.sh no encontrado o sin permisos de ejecución"

# ── Resumen ───────────────────────────────────────────────────────────────────
echo ""
echo -e "─────────────────────────────────────────"
TOTAL=$((PASS+FAIL+WARN))
if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  echo -e "${GRN}${BLD}✅ Entorno listo para la demo ($PASS/$TOTAL OK)${RST}"
elif [ "$FAIL" -eq 0 ]; then
  echo -e "${YEL}${BLD}⚠  Entorno casi listo — revisa los avisos ($WARN warnings, $PASS OK)${RST}"
else
  echo -e "${RED}${BLD}❌ Hay problemas que resolver antes de la demo ($FAIL fallos)${RST}"
fi
echo ""
