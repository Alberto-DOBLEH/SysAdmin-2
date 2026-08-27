#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/Modulos_Linux/contenedores.sh"

ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

MAIL_CONTAINER="mailserver"
DB_CONTAINER="roundcube-db"
WEBMAIL_CONTAINER="roundcubemail"
WEBMAIL_PORT=8081
MAIL_PORTS="25 143 587 993"

crear_env_si_falta() {
    if [ -f "$ENV_FILE" ]; then
        if grep -qP '\r' "$ENV_FILE" 2>/dev/null; then
            log_info "Corrigiendo saltos de linea CRLF en .env..."
            sed -i 's/\r$//' "$ENV_FILE"
        fi
        log_ok "Archivo .env existente."
        return 0
    fi

    cp "$ENV_EXAMPLE" "$ENV_FILE"
    sed -i 's/\r$//' "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    log_ok "Archivo .env creado desde .env.example. Puede editarlo antes de volver a ejecutar si desea otras credenciales."
}

cargar_env() {
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
}

instalar_dependencias_host() {
    log_info "Instalando dependencias del anfitrion: SSH, firewall y utilidades..."
    esperar_dpkg_lock
    apt-get update -y >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server ufw curl netcat-openbsd >/dev/null
    systemctl enable --now ssh >/dev/null 2>&1 || systemctl enable --now sshd >/dev/null 2>&1 || true
    log_ok "Dependencias del anfitrion listas."
}

configurar_firewall() {
    log_info "Configurando firewall del anfitrion..."
    ufw allow 22/tcp >/dev/null
    for puerto in $MAIL_PORTS $WEBMAIL_PORT; do
        ufw allow "${puerto}/tcp" >/dev/null
    done
    ufw --force enable >/dev/null
    log_ok "Firewall activo: SSH, SMTP/IMAP (25/143/587/993) y webmail (8081) permitidos."
}

levantar_stack() {
    log_info "Levantando stack de correo con Docker Compose..."
    cd "$SCRIPT_DIR"
    mkdir -p "$SCRIPT_DIR/logs"
    compose_cmd up -d
    log_ok "Stack iniciado."
}

esperar_servicio() {
    local contenedor="$1"
    local puerto="$2"
    local intentos=60

    log_info "Esperando a que $contenedor escuche en el puerto $puerto..."
    for _ in $(seq 1 "$intentos"); do
        if nc -z 127.0.0.1 "$puerto" >/dev/null 2>&1; then
            log_ok "$contenedor esta respondiendo en el puerto $puerto."
            return 0
        fi
        sleep 2
    done

    log_error "$contenedor no respondio en el puerto $puerto a tiempo."
    return 1
}

esperar_mailserver() {
    esperar_servicio "$MAIL_CONTAINER" 25
    log_info "Esperando a que $WEBMAIL_CONTAINER este activo..."
    for _ in $(seq 1 60); do
        if [ "$(docker inspect -f '{{.State.Status}}' "$WEBMAIL_CONTAINER" 2>/dev/null || echo starting)" = "running" ]; then
            log_ok "$WEBMAIL_CONTAINER esta activo."
            return 0
        fi
        sleep 2
    done
    log_error "$WEBMAIL_CONTAINER no inicio a tiempo."
    return 1
}

mostrar_resumen() {
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}')

    echo ""
    echo "================ Practica 12 desplegada ================"
    echo "Servidor de correo (SMTP/IMAP): ${server_ip} puertos 25 143 587 993"
    echo "Webmail (Roundcube):            http://${server_ip}:${WEBMAIL_PORT}"
    echo "Dominio:                        ${DOMAIN} (host ${HOSTNAME})"
    echo "Red Docker:                     red_correo + red_datos_interna"
    echo "Volumenes:                      mail_data, mail_state, roundcube_db_data"
    echo "Cuentas preconfiguradas (${DOMAIN}):"
    echo "  director, admin, kami, goku, vegeta"
    echo "Contrasena de las cuentas:      PasswordSegura123!"
    echo ""
    echo "Para anadir una cuenta nueva:"
    echo "  docker exec -it mailserver setup email add usuario@${DOMAIN} 'Contrasena'"
    echo ""
    echo "Pruebas rapidas:"
    echo "  docker exec -it mailserver setup email list"
    echo "  nc -zv ${server_ip} 25"
    echo "  curl -s -o /dev/null -w '%{http_code}' http://${server_ip}:${WEBMAIL_PORT}"
    echo ""
    echo "Guia completa: $SCRIPT_DIR/VALIDACION.md"
    echo "========================================================"
}

main() {
    require_root
    instalar_docker_si_falta
    instalar_docker_compose_si_falta
    instalar_dependencias_host
    crear_env_si_falta
    cargar_env
    configurar_firewall
    levantar_stack
    esperar_mailserver
    mostrar_resumen
}

main "$@"