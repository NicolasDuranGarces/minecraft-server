#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
BACKUP_DIR="$ROOT_DIR/backups/db"
if [[ -n "${COMPOSE:-}" ]]; then
  read -r -a COMPOSE_CMD <<<"${COMPOSE}"
else
  COMPOSE_CMD=(docker compose)
fi
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
  fi
}

require_compose() {
  if ! command -v docker >/dev/null; then
    echo "[backup_db] Docker no está instalado" >&2
    exit 1
  fi
}

require_service() {
  if ! "${COMPOSE_CMD[@]}" ps db >/dev/null 2>&1; then
    echo "[backup_db] El servicio db no está disponible. ¿Está el stack arriba?" >&2
    exit 1
  fi
}

create_dump() {
  mkdir -p "$BACKUP_DIR"
  local outfile="$BACKUP_DIR/${DB_NAME:-mc_auth}-$TIMESTAMP.sql.gz"
  echo "[backup_db] Generando dump en $outfile"
  if ! "${COMPOSE_CMD[@]}" exec -T -e "MYSQL_PWD=${DB_PASSWORD:-mc_auth_pass}" db mysqldump -u"${DB_USER:-mc_auth}" "${DB_NAME:-mc_auth}" | gzip >"$outfile"; then
    rm -f "$outfile"
    echo "[backup_db] Error al crear el dump" >&2
    exit 1
  fi
  echo "[backup_db] Backup completado."
}

load_env
require_compose
require_service
create_dump
