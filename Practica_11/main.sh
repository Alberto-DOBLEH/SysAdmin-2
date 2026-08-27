#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/Modulos_Linux/contenedores.sh"

ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

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
    apt-get update -y >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server ufw curl >/dev/null
    systemctl enable --now ssh >/dev/null 2>&1 || systemctl enable --now sshd >/dev/null 2>&1 || true
    log_ok "Dependencias del anfitrion listas."
}

configurar_firewall() {
    log_info "Configurando firewall del anfitrion..."
    ufw allow "${SSH_PORT}/tcp" >/dev/null
    ufw allow "${FRONTEND_PORT}/tcp" >/dev/null
    ufw deny 5432/tcp >/dev/null
    ufw deny 5050/tcp >/dev/null
    ufw --force enable >/dev/null
    log_ok "Firewall activo: SSH y frontend permitidos; PostgreSQL/pgAdmin bloqueados desde el exterior."
}

levantar_stack() {
    log_info "Levantando stack con Docker Compose..."
    cd "$SCRIPT_DIR"
    compose_cmd up -d --build
    log_ok "Stack iniciado."
}

actualizar_hosts_tunel() {
    local pgadmin_ip postgres_ip

    cd "$SCRIPT_DIR"
    pgadmin_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' servidor_pgadmin)
    postgres_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' servidor_postgres)

    sed -i '/ servidor_pgadmin$/d;/ servidor_postgres$/d' /etc/hosts
    echo "$pgadmin_ip servidor_pgadmin" >> /etc/hosts
    echo "$postgres_ip servidor_postgres" >> /etc/hosts

    log_ok "Nombres internos registrados en /etc/hosts para tuneles SSH."
}

mostrar_resumen() {
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}')

    echo ""
    echo "================ Practica 11 desplegada ================"
    echo "Frontend publico: http://${server_ip}:${FRONTEND_PORT}"
    echo "PostgreSQL: sin puerto publicado al host; servicio interno base_datos/servidor_postgres:5432"
    echo "pgAdmin: sin puerto publicado al host; servicio interno servidor_pgadmin:80"
    echo "Tunel pgAdmin desde la maquina del estudiante:"
    echo "  ssh -L 8080:servidor_pgadmin:80 usuario@${server_ip}"
    echo "  Abrir despues: http://localhost:8080"
    echo ""
    echo "Pruebas rapidas:"
    echo "  docker exec servidor_nginx ping -c 3 base_datos"
    echo "  docker compose --env-file $ENV_FILE -f $SCRIPT_DIR/docker-compose.yml ps"
    echo "  docker stats --no-stream"
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
    actualizar_hosts_tunel
    mostrar_resumen
}

main "$@"
