#!/bin/bash
# =============================================================================
# restore_postgres.sh — Restaura PostgreSQL desde el backup local (Plan B)
# Adaptado para HDM · Base de datos: hdm_db
#
# USO: ./restore_postgres.sh
# NOTA: El camino principal de recuperación es Zerto Journal.
#       Usa este script solo para resetear el entorno tras la demo.
# =============================================================================

set -euo pipefail

PGDATA="/var/lib/postgresql/16/main"
BACKUP_DIR="$(dirname "$0")/backup"
SERVICE_PG="postgresql"
PG_USER="postgres"

GRN='\033[0;32m'; RED='\033[0;31m'; YEL='\033[1;33m'
CYA='\033[0;36m'; BLD='\033[1m'; RST='\033[0m'

typewriter() {
  local text="$1"; local delay="${2:-0.03}"
  for (( i=0; i<${#text}; i++ )); do
    printf '%s' "${text:$i:1}"; sleep "$delay"
  done; echo
}

if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}ERROR: Ejecuta como root.${RST}"; exit 1
fi
if [ ! -d "$BACKUP_DIR/main" ]; then
  echo -e "${RED}ERROR: No se encuentra backup en $BACKUP_DIR/main${RST}"; exit 1
fi

clear; sleep 0.3
echo -e "${GRN}${BLD}"
cat << 'HERO_ART'

    ███████╗███████╗██████╗ ████████╗ ██████╗
    ╚══███╔╝██╔════╝██╔══██╗╚══██╔══╝██╔═══██╗
      ███╔╝ █████╗  ██████╔╝   ██║   ██║   ██║
     ███╔╝  ██╔══╝  ██╔══██╗   ██║   ██║   ██║
    ███████╗███████╗██║  ██║   ██║   ╚██████╔╝
    ╚══════╝╚══════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝

               R E C O V E R Y   M O D E

HERO_ART
echo -e "${RST}"
sleep 0.4
typewriter "  Wario pensaba que había ganado... pero Zerto estaba mirando." 0.04
sleep 0.3
typewriter "  Iniciando restauración desde backup local — plan B activado." 0.04
sleep 0.6
echo ""

BACKUP_SIZE=$(du -sh "$BACKUP_DIR/main" | awk '{print $1}')

# ── [1/5] Para PostgreSQL ─────────────────────────────────────────────────────
echo -e "${BLD}[1/5]${RST} Deteniendo PostgreSQL..."
systemctl stop "$SERVICE_PG" 2>/dev/null || true
sleep 2
echo -e "      ${GRN}✔ Detenido${RST}"

# ── [2/5] Elimina datos cifrados ─────────────────────────────────────────────
echo -e "\n${BLD}[2/5]${RST} Eliminando ficheros cifrados de Wario..."
SIZE_BEFORE=$(du -sh "$PGDATA" 2>/dev/null | awk '{print $1}' || echo "?")
rm -rf "$PGDATA"
echo -e "      ${GRN}✔ Datos cifrados eliminados ($SIZE_BEFORE borrados)${RST}"

# ── [3/5] Restaura desde backup ──────────────────────────────────────────────
echo -e "\n${BLD}[3/5]${RST} Restaurando datos limpios desde backup (~$BACKUP_SIZE)..."
(cp -a "$BACKUP_DIR/main" "$PGDATA") &
CP_PID=$!
while kill -0 "$CP_PID" 2>/dev/null; do
  for c in '⣾' '⣷' '⣯' '⣟' '⡿' '⢿' '⣻' '⣽'; do
    printf "\r      %s Copiando..." "$c"; sleep 0.1
  done
done
wait "$CP_PID"
echo -e "\r      ${GRN}✔ Datos restaurados en $PGDATA${RST}                    "

# ── [4/5] Restaura permisos ───────────────────────────────────────────────────
echo -e "\n${BLD}[4/5]${RST} Restaurando permisos de PostgreSQL..."
chown -R "$PG_USER:$PG_USER" "$PGDATA"
chmod 700 "$PGDATA"
echo -e "      ${GRN}✔ Permisos restaurados (propietario: $PG_USER)${RST}"

# ── [5/5] Arranca y verifica ──────────────────────────────────────────────────
echo -e "\n${BLD}[5/5]${RST} Arrancando PostgreSQL..."
systemctl start "$SERVICE_PG"
sleep 4
if PGPASSWORD=hdm_pass_2024 psql -h localhost -U hdm_user -d hdm_db \
    -c 'SELECT COUNT(*) FROM discharges;' -q -t > /dev/null 2>&1; then
  TOTAL=$(PGPASSWORD=hdm_pass_2024 psql -h localhost -U hdm_user -d hdm_db \
    -c 'SELECT COUNT(*) FROM discharges;' -q -t | tr -d ' ')
  echo -e "      ${GRN}✔ PostgreSQL respondiendo — $TOTAL altas en BD${RST}"
else
  echo -e "      ${RED}✗ PostgreSQL arrancó pero no responde — revisa logs:${RST}"
  echo -e "        journalctl -u postgresql -n 30 --no-pager"
  exit 1
fi

# ── Limpieza del backup ───────────────────────────────────────────────────────
echo ""
read -rp "  ¿Eliminar el backup local? (recomendado tras verificar) [s/N]: " CONFIRM
if [[ "$CONFIRM" =~ ^[sS]$ ]]; then
  rm -rf "$BACKUP_DIR"
  echo -e "      ${GRN}✔ Backup eliminado${RST}"
else
  echo -e "      ${YEL}Backup conservado en $BACKUP_DIR${RST}"
fi

# ── Pantalla final ────────────────────────────────────────────────────────────
clear; sleep 0.3
echo -e "${GRN}${BLD}"
cat << 'VICTORY_ART'

    ██████╗ ███████╗ ██████╗ ██████╗ ██╗   ██╗███████╗██████╗ ██╗
    ██╔══██╗██╔════╝██╔════╝██╔═══██╗██║   ██║██╔════╝██╔══██╗██║
    ██████╔╝█████╗  ██║     ██║   ██║██║   ██║█████╗  ██████╔╝██║
    ██╔══██╗██╔══╝  ██║     ██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗╚═╝
    ██║  ██║███████╗╚██████╗╚██████╔╝ ╚████╔╝ ███████╗██║  ██║██╗
    ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝

VICTORY_ART
echo -e "${RST}"
sleep 0.4
typewriter "  Wario ha sido derrotado. Los datos están SEGUROS." 0.04
sleep 0.3
typewriter "  El sistema hospitalario vuelve a estar operativo." 0.04
sleep 0.3
typewriter "  No se pagó ni una moneda a Wario. WAH!" 0.04
sleep 0.5
echo ""
echo -e "${GRN}${BLD}═══════════════════════════════════════════════════${RST}"
echo -e "  Base de datos  : ${GRN}RESTAURADA Y OPERATIVA${RST}"
echo -e "  Pérdida de datos: ${GRN}CERO (backup pre-ataque)${RST}"
echo -e "  Pagado a Wario : ${GRN}NADA${RST}"
echo -e "${GRN}${BLD}═══════════════════════════════════════════════════${RST}"
echo ""
echo -e "${YEL}  NOTA: Reinicia el backend HDM en VM2 si es necesario:${RST}"
echo -e "  ssh root@10.10.44.14 'systemctl restart hdm-backend'"
echo -e "${GRN}${BLD}═══════════════════════════════════════════════════${RST}"
echo ""
