COMPOSE ?= docker compose
SERVICE ?= mc

.PHONY: build up down logs restart backup-world backup-db shell

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
