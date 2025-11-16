COMPOSE ?= docker compose
SERVICE ?= mc
RCON_PASS ?= $(MC_RCON_PASSWORD)
RCON_HOST ?= 127.0.0.1
RCON_PORT ?= 25575

.PHONY: build up down logs restart backup-world backup-db shell
.PHONY: exec
.PHONY: mc-cmd
.PHONY: mc-rcon

build:
	$(COMPOSE) build $(SERVICE)

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f $(SERVICE)

restart:
	$(COMPOSE) restart $(SERVICE)

backup-world:
	bash scripts/backup_world.sh

backup-db:
	bash scripts/backup_db.sh

shell:
	$(COMPOSE) exec $(SERVICE) /bin/sh

# Ejecuta un comando arbitrario dentro del contenedor mc.
# Uso: make exec CMD="rcon-cli --password ... list"
exec:
	@if [ -z "$(CMD)" ]; then \
		echo "Error: define CMD=\"tu comando\""; \
		exit 1; \
	fi
	$(COMPOSE) exec $(SERVICE) sh -lc '$(CMD)'

# Envía un comando directo a la consola de Minecraft (stdin del proceso).
# Uso: make mc-cmd CMD="say hola"
mc-cmd:
	@if [ -z "$(CMD)" ]; then \
		echo "Error: define CMD=\"tu comando\""; \
		exit 1; \
	fi
	$(COMPOSE) exec -T $(SERVICE) sh -lc 'printf -- "%s\n" "$(CMD)" > /proc/1/fd/0'

# Envía un comando vía RCON usando mcrcon dentro del contenedor.
# Variables: CMD (requerida), RCON_PASS (se puede exportar desde .env), RCON_HOST, RCON_PORT.
# Ejemplo: make mc-rcon CMD="op CamelloEnfermo" RCON_PASS=RconPass_ChangeMe_2024
mc-rcon:
	@if [ -z "$(CMD)" ]; then \
		echo "Error: define CMD=\"tu comando\""; \
		exit 1; \
	fi
	@if [ -z "$(RCON_PASS)" ]; then \
		echo "Error: define RCON_PASS (puedes exportar MC_RCON_PASSWORD o pasar RCON_PASS=...)"; \
		exit 1; \
	fi
	$(COMPOSE) exec -T $(SERVICE) sh -lc 'mcrcon -H $(RCON_HOST) -P $(RCON_PORT) -p "$(RCON_PASS)" "$(CMD)"'
