# Servidor de Minecraft (Paper) en Docker

Stack listo para producción que ejecuta PaperMC 1.21.x en un contenedor Java dedicado, con MariaDB como backend y plugins preconfigurados para skins (SkinsRestorer) y rendimiento.

> **Versión por defecto**: El stack se construye con Paper 1.21.8. Cuando Mojang/Paper publiquen una subversión nueva solo debes modificar `PAPER_VERSION` en tu `.env` y ejecutar `docker compose build mc` para actualizarla.

## Requisitos previos
- Docker 24+ y Docker Compose v2
- Al menos 6 GB de RAM libres (4 GB para la JVM + margen para el resto de servicios)

## Puesta en marcha rápida
1. Copia el archivo `.env.example` a `.env` y ajusta contraseñas/valores sensibles.
2. Revisa la carpeta `config/` y personaliza `server.properties` y los YAML de los plugins.
3. Construye la imagen personalizada: `docker compose build mc`
4. Levanta el stack: `docker compose up -d`
5. Verifica logs del servidor: `docker compose logs -f mc`

La carpeta `data/` almacenará mundos, plugins descargados y configuraciones generadas por Paper. `db_data/` contiene la data de MariaDB.

## Objetivos de Make disponibles
| Comando | Acción |
| --- | --- |
| `make build` | Reconstruye la imagen del servicio `mc`. |
| `make up` | Levanta todo el stack (`docker compose up -d`). |
| `make down` | Detiene y elimina los servicios. |
| `make restart` | Reinicia únicamente el contenedor `mc`. |
| `make logs` | Sigue los logs del servidor de Minecraft. |
| `make backup-world` | Empaqueta `data/` en `backups/world/<fecha>.tar.gz`. |
| `make backup-db` | Ejecuta `mysqldump` dentro del servicio `db` y genera `backups/db/<fecha>.sql.gz`. |

## Variables clave
- `PAPER_VERSION` / `PAPER_BUILD`: controlan qué build de Paper se descarga durante la construcción de la imagen.
- `MC_JVM_FLAGS`: flags _tuned_ para la JVM; ajusta memoria según tu host.
- `MC_RCON_PASSWORD`: contraseña del canal RCON. Debe coincidir con `rcon.password` en `config/server.properties` (el entrypoint lo sincroniza).
- `DB_*`: credenciales usadas por SkinsRestorer. Cambia los valores en `.env` **y** en el YAML del plugin para mantener consistencia.
- `SKINSRESTORER_VERSION`: controla la versión fija descargada para SkinsRestorer.
- `LUCKPERMS_DOWNLOAD_URL` / `LUCKPERMS_FILENAME`: ajustan el origen y nombre final del JAR de LuckPerms (por defecto Spiget #28140).
- `SPARK_DOWNLOAD_URL` / `SPARK_FILENAME`: definen desde dónde descargar spark (por defecto Spiget #57242) y el nombre final del JAR.

## Plugins incluidos
| Plugin | Uso | Fuente |
| --- | --- | --- |
| SkinsRestorer 15.9.0 | Permite usar skins premium en servidores sin verificación online de Mojang. | GitHub Releases |
| LuckPerms (última build) | Sistema de permisos avanzado listo para redes/proxies. | Spiget (resource 28140) |
| spark (última build) | Perfilado de ticks, TPS y uso de memoria/CPU para detectar cuellos de botella. | Spiget (resource 57242) |
| Chunky (última build) | Pre-generador de chunks para reducir picos de carga. | Spiget (resource 81534) |
| FarmLimiter (última build) | Limita densidad de mobs/entidades para mejorar rendimiento. | Spiget (resource 120384) |
| Alternate Current (última build) | Optimiza cálculos de redstone para reducir lag. | Spiget (resource 96380) |
| Multiverse-Core (última build) | Gestiona múltiples mundos (lobby, parkour, survival) en el mismo servidor. | Spiget (resource 390) |
| Multiverse-Portals (última build) | Crea portales/selección para moverse entre mundos. | Spiget (resource 296) |
| VoidGen (última build) | Generador de mundos vacíos ideal para lobbies ligeros. | Spiget (resource 63689) |

Todos los JAR listados se descargan automáticamente al iniciar el contenedor (`scripts/entrypoint.sh`). Si quieres forzar una actualización elimina los archivos en `data/plugins/` y reinicia el servicio.

## Base de datos
El servicio `db` expone MariaDB en el puerto 3306 y crea la base declarada en `DB_NAME`. SkinsRestorer utiliza tablas dentro de esa base. Puedes conectarte con cualquier cliente MySQL externo utilizando las credenciales definidas en `.env`.

## Operación segura
- Cambia **todas** las contraseñas por defecto antes de abrir puertos públicamente.
- Ajusta `online-mode` según tu necesidad: `true` para autenticación de Mojang (recomendado sin plugin de login), `false` solo si sabes lo que implica para clientes offline.
- Configura _whitelist_ editando `config/whitelist.json` (el archivo se copiará automáticamente a `data/`).
- Programa copias de seguridad periódicas de `data/` y `db_data/`.

## Comandos útiles
- Ver logs en vivo: `docker compose logs -f mc`
- Parar servicios: `docker compose down`
- Actualizar Paper a otra versión: ajusta `PAPER_VERSION`, reconstruye (`docker compose build mc`) y reinicia.
- Ejecutar comandos dentro del servidor: `docker compose exec mc rcon-cli --host mc --port 25575 --password <MC_RCON_PASSWORD>` (instala `rcon-cli` en tu host) o usa la consola interactiva `docker compose attach mc`.
- Backups rápidos: `make backup-world` para el mundo/archivos del servidor y `make backup-db` para la base de datos de autenticación/skins.

## Personalizaciones adicionales
- Añade más plugins colocando sus JAR en `config/plugins/<Plugin>/` o directamente dentro de `data/plugins/` (se mantendrán gracias al volumen).
- Ajusta reglas avanzadas de Paper editando `config/paper-global.yml` o archivos adicionales que coloques en `config/`.
- Para usar un proxy (Velocity/BungeeCord) expón `minecraft_mc` únicamente a la red interna y publica solo el proxy.

## Estructura
```
├── Makefile               # Atajos para build/up/logs/backups
├── Dockerfile              # Imagen Java con Paper + entrypoint
├── docker-compose.yml      # Servicios mc + db
├── config/                 # Configs base que se copian a /data al primer arranque
│   ├── server.properties
│   └── plugins/
│       └── SkinsRestorer/config.yml
├── scripts/entrypoint.sh   # Copia configs, aplica parches y lanza Paper
├── scripts/backup_*.sh     # Scripts para respaldar mundo y base de datos
├── data/                   # Mundo y plugins (volumen)
├── db_data/                # Datos MariaDB (volumen)
├── backups/                # Artefactos .tar.gz y .sql.gz generados por Make
└── .env.example
```

## Próximos pasos recomendados
1. Configura records DNS y un _reverse proxy_ TCP si vas a publicar el servidor a Internet.
2. Integra monitoreo (Prometheus/Grafana o servicios externos) usando métricas de Paper.
3. Automatiza backups con cronjobs externos o servicios como Velero/Borg.
