#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/Modulos_Linux/contenedores.sh"

NETWORK_NAME="infra_red"
NETWORK_SUBNET="172.20.0.0/16"
WEB_VOLUME="web_content"
DB_VOLUME="db_data"
BACKUP_DIR="/opt/sysadmin10/backups"

WEB_IMAGE="sysadmin10-web:1.0"
FTP_IMAGE="sysadmin10-ftp:1.0"

WEB_CONTAINER="sysadmin10_web"
DB_CONTAINER="sysadmin10_postgres"
FTP_CONTAINER="sysadmin10_ftp"

POSTGRES_USER="admin"
POSTGRES_PASSWORD="SysAdmin10!"
POSTGRES_DB="usuarios"

FTP_USER="ftpadmin"
FTP_PASSWORD="SysAdmin10!"
SERVER_IP=""

seleccionar_ip_publicacion() {
    mapfile -t ips < <(hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')

    if [ "${#ips[@]}" -eq 0 ]; then
        log_error "No se detecto ninguna IPv4 para publicar los servicios."
        exit 1
    fi

    if [ "${#ips[@]}" -eq 1 ]; then
        SERVER_IP="${ips[0]}"
        log_ok "Usando IP $SERVER_IP para publicar Web/FTP."
        return 0
    fi

    echo "Se detectaron varias IP en el servidor:"
    local indice=1
    for ip in "${ips[@]}"; do
        echo "  [$indice] $ip"
        indice=$((indice + 1))
    done

    while true; do
        read -r -p "Seleccione la IP interna para publicar Web/FTP: " opcion
        if [[ "$opcion" =~ ^[0-9]+$ ]] && [ "$opcion" -ge 1 ] && [ "$opcion" -le "${#ips[@]}" ]; then
            SERVER_IP="${ips[$((opcion - 1))]}"
            log_ok "Usando IP $SERVER_IP para publicar Web/FTP."
            break
        fi
        echo "Opcion invalida."
    done
}

deploy_postgres() {
    eliminar_contenedor_si_existe "$DB_CONTAINER"

    log_info "Levantando PostgreSQL con volumen persistente $DB_VOLUME..."
    docker run -d \
        --name "$DB_CONTAINER" \
        --network "$NETWORK_NAME" \
        --memory 512m \
        --cpus 0.50 \
        --restart unless-stopped \
        -e POSTGRES_USER="$POSTGRES_USER" \
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        -e POSTGRES_DB="$POSTGRES_DB" \
        -v "$DB_VOLUME:/var/lib/postgresql/data" \
        -p 5432:5432 \
        postgres:16-alpine >/dev/null

    esperar_postgres "$DB_CONTAINER" "$POSTGRES_USER"
    docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE TABLE IF NOT EXISTS usuarios_app (id serial PRIMARY KEY, usuario text NOT NULL, creado_en timestamp DEFAULT now());" >/dev/null
    docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "INSERT INTO usuarios_app(usuario) SELECT 'admin_demo' WHERE NOT EXISTS (SELECT 1 FROM usuarios_app WHERE usuario = 'admin_demo');" >/dev/null
    log_ok "Base $POSTGRES_DB inicializada con tabla usuarios_app."
}

deploy_web() {
    build_imagen "$WEB_IMAGE" "$SCRIPT_DIR/web"
    sembrar_contenido_web "$WEB_VOLUME" "$SCRIPT_DIR/web/site"
    eliminar_contenedor_si_existe "$WEB_CONTAINER"

    log_info "Levantando servidor web personalizado en puerto 8080..."
    docker run -d \
        --name "$WEB_CONTAINER" \
        --network "$NETWORK_NAME" \
        --memory 512m \
        --cpus 0.50 \
        --restart unless-stopped \
        -v "$WEB_VOLUME:/usr/share/nginx/html:ro" \
        -p 8080:8080 \
        "$WEB_IMAGE" >/dev/null

    log_ok "Servidor web disponible en http://IP_DEL_SERVIDOR:8080."
}

deploy_ftp() {
    build_imagen "$FTP_IMAGE" "$SCRIPT_DIR/ftp"
    eliminar_contenedor_si_existe "$FTP_CONTAINER"

    log_info "Levantando FTP para cargar archivos al volumen web_content..."
    docker run -d \
        --name "$FTP_CONTAINER" \
        --network "$NETWORK_NAME" \
        --memory 512m \
        --cpus 0.50 \
        --restart unless-stopped \
        -e FTP_USER="$FTP_USER" \
        -e FTP_PASSWORD="$FTP_PASSWORD" \
        -e PASV_ADDRESS="$SERVER_IP" \
        -v "$WEB_VOLUME:/home/ftpuser/files" \
        -p 21:21 \
        -p 21100-21110:21100-21110 \
        "$FTP_IMAGE" >/dev/null

    log_ok "FTP disponible en puerto 21. Usuario: $FTP_USER"
}

mostrar_resumen() {
    echo ""
    echo "================ Practica 10 desplegada ================"
    echo "Web:        http://${SERVER_IP}:8080"
    echo "PostgreSQL: contenedor $DB_CONTAINER, base $POSTGRES_DB, usuario $POSTGRES_USER"
    echo "FTP:        ftp://${SERVER_IP} usuario $FTP_USER password $FTP_PASSWORD"
    echo "Red Docker: $NETWORK_NAME ($NETWORK_SUBNET)"
    echo "Volumen BD: $DB_VOLUME"
    echo "Volumen Web/FTP: $WEB_VOLUME"
    echo "Backups BD: $BACKUP_DIR"
    echo ""
    echo "Validaciones rapidas:"
    echo "  docker stats --no-stream"
    echo "  docker exec $WEB_CONTAINER ping -c 3 $DB_CONTAINER"
    echo "  docker exec $DB_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB -c '\\l'"
    echo "  curl http://${SERVER_IP}:8080"
    echo ""
    echo "Guia completa: $SCRIPT_DIR/VALIDACION.md"
    echo "========================================================"
}

main() {
    require_root
    instalar_docker_si_falta
    seleccionar_ip_publicacion

    crear_red_bridge "$NETWORK_NAME" "$NETWORK_SUBNET"
    crear_volumen "$DB_VOLUME"
    crear_volumen "$WEB_VOLUME"

    deploy_postgres
    deploy_web
    deploy_ftp
    instalar_timer_respaldo_postgres "$DB_CONTAINER" "$POSTGRES_USER" "$BACKUP_DIR"

    mostrar_resumen
}

main "$@"
