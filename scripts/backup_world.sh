#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${DATA_DIR:-$ROOT_DIR/data}"
BACKUP_DIR="$ROOT_DIR/backups/world"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$BACKUP_DIR/world-$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

if [[ ! -d "$DATA_DIR" ]]; then
  echo "[backup_world] No se encontró la carpeta de datos en $DATA_DIR" >&2
  exit 1
fi

printf '[backup_world] Creando archivo %s\n' "$ARCHIVE"

tar -czf "$ARCHIVE" -C "$DATA_DIR" .

printf '[backup_world] Backup completado.\n'
