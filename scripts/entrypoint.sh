#!/usr/bin/env bash
set -euo pipefail

DATA_DIR=${DATA_DIR:-/data}
CONFIG_DIR=${CONFIG_DIR:-/config}
PAPER_JAR=${PAPER_JAR:-/opt/paper/paperclip.jar}
PLUGINS_DIR="$DATA_DIR/plugins"
SKINSRESTORER_VERSION=${SKINSRESTORER_VERSION:-15.9.0}
LUCKPERMS_DOWNLOAD_URL=${LUCKPERMS_DOWNLOAD_URL:-https://api.spiget.org/v2/resources/28140/download}
LUCKPERMS_FILENAME=${LUCKPERMS_FILENAME:-LuckPerms.jar}
SPARK_DOWNLOAD_URL=${SPARK_DOWNLOAD_URL:-https://api.spiget.org/v2/resources/57242/download}
SPARK_FILENAME=${SPARK_FILENAME:-spark.jar}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

require_eula() {
  local value=${EULA:-false}
  if [[ "${value,,}" != "true" ]]; then
    log "Debes aceptar la EULA de Minecraft (EULA=true) antes de iniciar el servidor."
    exit 64
  fi
  echo "eula=true" >"$DATA_DIR/eula.txt"
}

sync_config() {
  if [[ -d "$CONFIG_DIR" ]]; then
    log "Sincronizando configuraciones iniciales en $DATA_DIR"
    rsync -a --ignore-existing "$CONFIG_DIR"/ "$DATA_DIR"/ || true
  fi
  mkdir -p "$PLUGINS_DIR"
}

patch_property() {
  local key=$1
  local value=$2
  local file="$DATA_DIR/server.properties"
  [[ -f "$file" ]] || return
  if grep -q "^${key}=" "$file"; then
    sed -i.bak "s/^${key}=.*/${key}=${value}/" "$file"
  else
    echo "${key}=${value}" >>"$file"
  fi
  rm -f "${file}.bak"
}

patch_yaml_key() {
  local file=$1
  local key=$2
  local value=$3
  [[ -f "$file" ]] || return
  local escaped
  escaped=$(printf '%s' "$value" | sed -e 's/[&/]/\\&/g')
  sed -i.bak -E "s|^([[:space:]]*${key}:[[:space:]]*).*$|\1${escaped}|" "$file" || true
  rm -f "${file}.bak"
}

patch_yaml_root_key() {
  local file=$1
  local key=$2
  local value=$3

  if [[ ! -f "$file" ]]; then
    echo "${key}: ${value}" >"$file"
    return
  fi

  local escaped
  escaped=$(printf '%s' "$value" | sed -e 's/[&/]/\\&/g')
  if grep -qE "^${key}:" "$file"; then
    sed -i.bak -E "s|^${key}:[[:space:]]*.*|${key}: ${escaped}|" "$file" || true
  else
    echo "${key}: ${value}" >>"$file"
  fi
  rm -f "${file}.bak"
}

sync_plugin_db_configs() {
  local skins_config="$DATA_DIR/plugins/SkinsRestorer/config.yml"

  patch_yaml_key "$skins_config" "Host" "${DB_HOST:-db}"
  patch_yaml_key "$skins_config" "Port" "${DB_PORT:-3306}"
  patch_yaml_key "$skins_config" "Database" "${DB_NAME:-mc_auth}"
  patch_yaml_key "$skins_config" "Username" "${DB_USER:-mc_auth}"
  patch_yaml_key "$skins_config" "Password" "${DB_PASSWORD:-mc_auth_pass}"
}

remove_authme_plugin() {
  rm -f "$PLUGINS_DIR"/AuthMe-*.jar "$PLUGINS_DIR"/AuthMe.jar 2>/dev/null || true
}

ensure_no_connection_throttle() {
  local bukkit_file="$DATA_DIR/bukkit.yml"
  local paper_file="$DATA_DIR/paper-global.yml"

  # Reescribe con un YAML válido para evitar corrupciones previas.
  cat >"$bukkit_file" <<'EOF'
settings:
  allow-end: true
  warn-on-overload: false
  permissions-file: permissions.yml
  update-folder: update
  plugin-profiling: false
  connection-throttle: -1
  query-plugins: true
  deprecated-verbose: default
  shutdown-message: Server closed
  minimum-api: none
  use-map-color-cache: true
EOF

  cat >"$paper_file" <<'EOF'
settings:
  login-connection-throttle: -1
EOF
}

ensure_op_camello() {
  local file="$DATA_DIR/ops.json"
  local name="CamelloEnfermo"
  local online_mode="${ONLINE_MODE:-}"
  if [[ -z "$online_mode" && -f "$DATA_DIR/server.properties" ]]; then
    online_mode=$(grep -E '^online-mode=' "$DATA_DIR/server.properties" | cut -d'=' -f2)
  fi
  local uuid=""

  if [[ "${online_mode,,}" == "true" ]]; then
    # intentar UUID premium
    uuid=$(curl -fsSL "https://api.mojang.com/users/profiles/minecraft/${name}" | python3 - <<'PY'
import json,sys
data=sys.stdin.read().strip()
if not data:
    sys.exit(1)
obj=json.loads(data)
raw=obj.get("id","")
if len(raw)!=32:
    sys.exit(1)
uuid=f"{raw[0:8]}-{raw[8:12]}-{raw[12:16]}-{raw[16:20]}-{raw[20:]}"
print(uuid)
PY) || uuid=""
    if [[ -z "$uuid" ]]; then
      log "No se pudo obtener UUID premium de CamelloEnfermo; usando UUID offline"
    fi
  fi

  if [[ -z "$uuid" ]]; then
    uuid=$(python3 - <<'PY'
import uuid
print(uuid.uuid3(uuid.NAMESPACE_DNS, "OfflinePlayer:CamelloEnfermo"))
PY)
  fi

  python3 - "$file" "$name" "$uuid" <<'PY'
import json, os, sys
file, name, uuid = sys.argv[1], sys.argv[2], sys.argv[3]
entry = {"uuid": uuid, "name": name, "level": 4, "bypassesPlayerLimit": True}
data = []
if os.path.exists(file):
    try:
        with open(file, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        data = []
if not any((e.get("uuid") == uuid) or (e.get("name", "").lower() == name.lower()) for e in data):
    data.append(entry)
    with open(file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
PY
  log "Ops actualizado para ${name} (${uuid})"
}

download_plugin() {
  local name=$1
  local url=$2
  local destination=$3

  local urls=()
  # permitir lista separada por coma
  IFS=',' read -r -a urls <<<"$url"

  if [[ -f "$destination" ]] && unzip -t "$destination" >/dev/null 2>&1; then
    log "${name} ya presente"
    return
  fi

  [[ -f "$destination" ]] && log "${name} corrupto, re-descargando" && rm -f "$destination"

  for u in "${urls[@]}"; do
    u="${u//[[:space:]]/}"
    [[ -z "$u" ]] && continue
    log "Descargando ${name} desde ${u}"
    tmp="${destination}.tmp"
    if curl -fsSL -o "$tmp" "$u" && unzip -t "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$destination"
      return
    fi
    rm -f "$tmp"
    log "Fallo descargando ${name} desde ${u}, probando siguiente origen"
  done

  log "No se pudo descargar ${name}; revisa la conectividad o URLs"
}

install_plugins() {
  local skins_url="https://github.com/SkinsRestorer/SkinsRestorer/releases/download/${SKINSRESTORER_VERSION}/SkinsRestorer.jar"
  local luckperms_url="${LUCKPERMS_DOWNLOAD_URL}"
  local spark_url="${SPARK_DOWNLOAD_URL}"
  local chunky_url="https://api.spiget.org/v2/resources/81534/download"
  local farmlimiter_url="https://api.spiget.org/v2/resources/120384/download"
  local alternatecurrent_url="https://api.spiget.org/v2/resources/96380/download"
  # Multiverse: usamos builds oficiales de Jenkins (más estables que descargas de Spiget)
  local multiverse_core_url="https://github.com/Multiverse/Multiverse-Core/releases/download/5.3.4/multiverse-core-5.3.4.jar,https://api.spiget.org/v2/resources/390/download,https://ci.onarandombox.com/job/Multiverse-Core/lastSuccessfulBuild/artifact/target/Multiverse-Core-4.3.1-SNAPSHOT.jar"
  local multiverse_portals_url="https://github.com/Multiverse/Multiverse-Portals/releases/download/5.1.1/multiverse-portals-5.1.1.jar,https://api.spiget.org/v2/resources/296/download,https://ci.onarandombox.com/job/Multiverse-Portals/lastSuccessfulBuild/artifact/target/Multiverse-Portals-4.3.1-SNAPSHOT.jar"
  local voidgen_url="https://api.spiget.org/v2/resources/63689/download"

  local plugins=(
    "SkinsRestorer|$skins_url|SkinsRestorer-${SKINSRESTORER_VERSION}.jar"
    "LuckPerms|$luckperms_url|${LUCKPERMS_FILENAME}"
    "spark|$spark_url|${SPARK_FILENAME}"
    "Chunky|$chunky_url|Chunky.jar"
    "FarmLimiter|$farmlimiter_url|FarmLimiter.jar"
    "AlternateCurrent|$alternatecurrent_url|AlternateCurrent.jar"
    "Multiverse-Core|$multiverse_core_url|Multiverse-Core.jar"
    "Multiverse-Portals|$multiverse_portals_url|Multiverse-Portals.jar"
    "VoidGen|$voidgen_url|VoidGen.jar"
  )

  local entry name url filename
  for entry in "${plugins[@]}"; do
    IFS="|" read -r name url filename <<<"$entry"
    download_plugin "$name" "$url" "$PLUGINS_DIR/$filename"
  done
}

bootstrap() {
  mkdir -p "$DATA_DIR"
  require_eula
  sync_config

  [[ -f "$DATA_DIR/server.properties" ]] || touch "$DATA_DIR/server.properties"

  if [[ -n "${MC_MAX_PLAYERS:-}" ]]; then
    patch_property "max-players" "$MC_MAX_PLAYERS"
  fi

  if [[ -n "${MC_DIFFICULTY:-}" ]]; then
    patch_property "difficulty" "$MC_DIFFICULTY"
  fi

  if [[ -n "${MC_RCON_PASSWORD:-}" ]]; then
    patch_property "rcon.password" "$MC_RCON_PASSWORD"
  fi

  install_plugins
  sync_plugin_db_configs
  ensure_no_connection_throttle
  ensure_op_camello
  remove_authme_plugin
}

start_server() {
  cd "$DATA_DIR"
  log "Arrancando Paper con flags: ${JVM_FLAGS:-no definidos}"
  exec java ${JVM_FLAGS:- -Xms2G -Xmx2G} -jar "$PAPER_JAR" --nogui
}

bootstrap
start_server
