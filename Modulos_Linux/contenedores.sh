#!/bin/bash

log_info() {
    echo "[INFO] $*"
}

log_ok() {
    echo "[OK] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Ejecute este script con sudo o como root."
        exit 1
    fi
}

instalar_docker_si_falta() {
    if command -v docker >/dev/null 2>&1; then
        log_ok "Docker ya esta instalado."
    else
        log_info "Instalando Docker y dependencias minimas..."
        apt-get update -y >/dev/null
        DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io curl ca-certificates >/dev/null
        log_ok "Docker instalado."
    fi

    systemctl enable --now docker >/dev/null 2>&1 || service docker start >/dev/null 2>&1
}

instalar_docker_compose_si_falta() {
    if docker compose version >/dev/null 2>&1; then
        log_ok "Docker Compose plugin ya esta disponible."
        return 0
    fi

    if command -v docker-compose >/dev/null 2>&1; then
        log_ok "docker-compose ya esta disponible."
        return 0
    fi

    log_info "Instalando Docker Compose..."
    apt-get update -y >/dev/null

    if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin >/dev/null
    else
        DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose >/dev/null
    fi

    log_ok "Docker Compose instalado."
}

compose_cmd() {
    if docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    else
        docker-compose "$@"
    fi
}

crear_red_bridge() {
    local nombre_red="$1"
    local segmento="$2"

    if docker network inspect "$nombre_red" >/dev/null 2>&1; then
        log_ok "La red $nombre_red ya existe."
        return 0
    fi

    log_info "Creando red bridge $nombre_red con segmento $segmento..."
    docker network create --driver bridge --subnet "$segmento" "$nombre_red" >/dev/null
    log_ok "Red $nombre_red creada."
}

crear_volumen() {
    local volumen="$1"

    if docker volume inspect "$volumen" >/dev/null 2>&1; then
        log_ok "El volumen $volumen ya existe."
        return 0
    fi

    log_info "Creando volumen $volumen..."
    docker volume create "$volumen" >/dev/null
    log_ok "Volumen $volumen creado."
}

build_imagen() {
    local etiqueta="$1"
    local contexto="$2"

    log_info "Construyendo imagen $etiqueta..."
    docker build -t "$etiqueta" "$contexto" >/dev/null
    log_ok "Imagen $etiqueta lista."
}

eliminar_contenedor_si_existe() {
    local contenedor="$1"

    if docker ps -a --format '{{.Names}}' | grep -qx "$contenedor"; then
        log_info "Recreando contenedor $contenedor..."
        docker rm -f "$contenedor" >/dev/null
    fi
}

esperar_postgres() {
    local contenedor="$1"
    local usuario="$2"
    local intentos=30

    log_info "Esperando a que PostgreSQL este listo..."
    for _ in $(seq 1 "$intentos"); do
        if docker exec "$contenedor" pg_isready -U "$usuario" >/dev/null 2>&1; then
            log_ok "PostgreSQL esta listo."
            return 0
        fi
        sleep 2
    done

    log_error "PostgreSQL no respondio a tiempo. Revise docker logs $contenedor."
    return 1
}

sembrar_contenido_web() {
    local volumen="$1"
    local origen="$2"

    log_info "Copiando contenido web personalizado al volumen $volumen..."
    docker run --rm \
        -v "$volumen:/target" \
        -v "$origen:/source:ro" \
        alpine:3.20 \
        sh -c 'cp -a /source/. /target/ && chown -R 1000:1000 /target' >/dev/null
    log_ok "Contenido web inicial disponible en $volumen."
}

instalar_timer_respaldo_postgres() {
    local contenedor="$1"
    local usuario="$2"
    local carpeta_backups="$3"

    mkdir -p "$carpeta_backups"

    cat > /usr/local/bin/sysadmin10_pg_backup.sh <<EOF_BACKUP
#!/bin/bash
set -euo pipefail

BACKUP_DIR="$carpeta_backups"
CONTAINER="$contenedor"
POSTGRES_USER="$usuario"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)

mkdir -p "\$BACKUP_DIR"
docker exec "\$CONTAINER" pg_dumpall -U "\$POSTGRES_USER" > "\$BACKUP_DIR/postgres_\$TIMESTAMP.sql"
find "\$BACKUP_DIR" -type f -name 'postgres_*.sql' -mtime +7 -delete
EOF_BACKUP

    chmod +x /usr/local/bin/sysadmin10_pg_backup.sh

    cat > /etc/systemd/system/sysadmin10-pg-backup.service <<'EOF_SERVICE'
[Unit]
Description=SysAdmin practice 10 PostgreSQL backup
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sysadmin10_pg_backup.sh
EOF_SERVICE

    cat > /etc/systemd/system/sysadmin10-pg-backup.timer <<'EOF_TIMER'
[Unit]
Description=Run SysAdmin practice 10 PostgreSQL backup every 10 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=10min
Persistent=true

[Install]
WantedBy=timers.target
EOF_TIMER

    systemctl daemon-reload
    systemctl enable --now sysadmin10-pg-backup.timer >/dev/null
    /usr/local/bin/sysadmin10_pg_backup.sh

    log_ok "Respaldo automatizado configurado en $carpeta_backups."
}
