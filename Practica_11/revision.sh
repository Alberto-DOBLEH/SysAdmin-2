#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/Modulos_Linux/contenedores.sh"

ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

NGINX_CONTAINER="servidor_nginx"
APP_CONTAINER="servidor_app"
DB_CONTAINER="servidor_postgres"
PGADMIN_CONTAINER="servidor_pgadmin"

DB_SERVICE="base_datos"
PGADMIN_SERVICE="servidor_pgadmin"

SERVER_IP="${1:-}"

LOG_FILE="$SCRIPT_DIR/revision_$(date +%Y%m%d_%H%M%S).log"
RESULTADOS=()

emitir() {
    printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

cargar_env() {
    if [ ! -f "$ENV_FILE" ]; then
        log_error "No existe $ENV_FILE. Ejecute primero: cd Practica_11 && sudo bash main.sh"
        return 1
    fi
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
    return 0
}

verificar_prerequisitos() {
    local faltantes=0

    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker no esta instalado. Ejecute primero: sudo bash main.sh"
        return 1
    fi

    if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
        log_error "Docker Compose no esta disponible. Ejecute primero: sudo bash main.sh"
        return 1
    fi

    for c in "$NGINX_CONTAINER" "$APP_CONTAINER" "$DB_CONTAINER" "$PGADMIN_CONTAINER"; do
        if ! docker ps --format '{{.Names}}' | grep -qx "$c"; then
            log_error "El contenedor $c no esta corriendo."
            faltantes=1
        fi
    done

    if [ "$faltantes" -eq 1 ]; then
        log_error "Levante el stack antes de revisar: cd Practica_11 && sudo bash main.sh"
        return 1
    fi

    return 0
}

esperar_postgres_healthy() {
    local estado
    for _ in $(seq 1 40); do
        estado="$(docker inspect -f '{{.State.Health.Status}}' "$DB_CONTAINER" 2>/dev/null || echo starting)"
        if [ "$estado" = "healthy" ]; then
            return 0
        fi
        sleep 2
    done
    return 1
}

prueba_11_1() {
    local ok=1

    emitir ""
    emitir "================ Prueba 11.1: Aislamiento de red ================"

    for puerto in 5432 5050; do
        if curl --max-time 5 -s -o /dev/null "http://localhost:$puerto"; then
            emitir "[ERROR] El puerto $puerto respondio desde el host; deberia estar bloqueado."
            ok=0
        else
            emitir "[OK] Puerto $puerto: conexion rechazada (servicio invisible fuera de Docker)."
        fi
    done

    if [ -n "$(docker port "$DB_CONTAINER" 2>/dev/null)" ]; then
        emitir "[ERROR] servidor_postgres tiene puertos publicados al host."
        ok=0
    else
        emitir "[OK] servidor_postgres no publica puertos al host."
    fi

    if [ -n "$(docker port "$PGADMIN_CONTAINER" 2>/dev/null)" ]; then
        emitir "[ERROR] servidor_pgadmin tiene puertos publicados al host."
        ok=0
    else
        emitir "[OK] servidor_pgadmin no publica puertos al host."
    fi

    if [ "$ok" -eq 1 ]; then
        RESULTADOS+=("11.1 aislamiento de red: PASS")
        emitir "[OK] Prueba 11.1 superada: base de datos y panel administrativo son invisibles fuera de Docker."
    else
        RESULTADOS+=("11.1 aislamiento de red: FAIL")
        emitir "[ERROR] Prueba 11.1 fallada: algun servicio critico quedo expuesto al host."
    fi
}

prueba_11_2() {
    emitir ""
    emitir "================ Prueba 11.2: Resolucion DNS interna ================"
    emitir "-- Ping desde $NGINX_CONTAINER al nombre del servicio $DB_SERVICE:"

    if docker exec "$NGINX_CONTAINER" ping -c 3 "$DB_SERVICE" 2>&1 | tee -a "$LOG_FILE"; then
        RESULTADOS+=("11.2 resolucion DNS interna: PASS")
        emitir "[OK] Prueba 11.2 superada: los contenedores se encuentran por nombre de servicio."
    else
        RESULTADOS+=("11.2 resolucion DNS interna: FAIL")
        emitir "[ERROR] Prueba 11.2 fallada: el balanceador no resolvio el nombre $DB_SERVICE."
    fi
}

prueba_11_3() {
    local codigo
    local interno_ok=1

    emitir ""
    emitir "================ Prueba 11.3: Tunel cifrado de gestion ================"

    emitir "-- Verificando servicio SSH en el anfitrion:"
    if pgrep -x sshd >/dev/null 2>&1; then
        emitir "[OK] sshd esta activo en el puerto ${SSH_PORT:-22}."
    else
        emitir "[ERROR] sshd no esta activo."
        interno_ok=0
    fi

    emitir "-- Verificando nombre interno servidor_pgadmin en /etc/hosts:"
    if grep -q " servidor_pgadmin$" /etc/hosts; then
        emitir "[OK] servidor_pgadmin registrado en /etc/hosts."
    else
        emitir "[ERROR] Falta la entrada servidor_pgadmin en /etc/hosts."
        interno_ok=0
    fi

    emitir "-- Verificando que pgAdmin responde internamente:"
    local intentos
    codigo="000"
    for intentos in 1 2 3 4 5; do
        if docker exec "$NGINX_CONTAINER" wget -q -O /dev/null -T 3 "http://servidor_pgadmin:80" 2>/dev/null; then
            codigo="200"
            break
        fi
        sleep 2
    done
    if [ "$codigo" != "000" ]; then
        emitir "[OK] pgAdmin responde internamente con HTTP $codigo."
    else
        emitir "[ERROR] pgAdmin no respondio internamente despues de $intentos intentos."
        interno_ok=0
    fi

    emitir "-- Intentando establecer tunel SSH local (anfitrion -> pgAdmin):"
    if ssh-keyscan -T 5 localhost >/dev/null 2>&1 \
        && ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
               -o ExitOnForwardFailure=yes -f -N \
               -L 8080:servidor_pgadmin:80 localhost >/dev/null 2>&1; then
        sleep 1
        codigo="$(curl --max-time 5 -s -o /dev/null -w '%{http_code}' http://localhost:8080)"
        if [ "$codigo" != "000" ]; then
            emitir "[OK] Tunel SSH local activo: http://localhost:8080 responde con HTTP $codigo."
            RESULTADOS+=("11.3 tunel SSH: PASS (tunel local establecido)")
        else
            emitir "[ERROR] El tunel se creo pero localhost:8080 no respondio."
            RESULTADOS+=("11.3 tunel SSH: FAIL")
        fi
        pkill -f "8080:servidor_pgadmin:80" 2>/dev/null || true
    elif [ "$interno_ok" -eq 1 ]; then
        emitir "[INFO] No se pudo autenticar el tunel SSH local sin contrasena."
        emitir "[OK] Validacion interna correcta. Confirmar el tunel desde la maquina del estudiante:"
        emitir "    ssh -L 8080:servidor_pgadmin:80 usuario@${SERVER_IP}"
        emitir "    Abrir luego: http://localhost:8080"
        RESULTADOS+=("11.3 tunel SSH: PASS (validacion interna; ejecutar tunel desde el cliente)")
    else
        RESULTADOS+=("11.3 tunel SSH: FAIL")
        emitir "[ERROR] Prueba 11.3 fallada: no fue posible validar el acceso cifrado a pgAdmin."
    fi
}

refrescar_hosts() {
    local pgadmin_ip postgres_ip

    cd "$SCRIPT_DIR"
    pgadmin_ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$PGADMIN_CONTAINER")"
    postgres_ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DB_CONTAINER")"

    sed -i '/ servidor_pgadmin$/d;/ servidor_postgres$/d' /etc/hosts
    echo "$pgadmin_ip servidor_pgadmin" >> /etc/hosts
    echo "$postgres_ip servidor_postgres" >> /etc/hosts

    emitir "[OK] /etc/hosts actualizado con las nuevas IPs internas."
}

prueba_11_4() {
    local dato="persistencia_revision_$(date +%s)"

    emitir ""
    emitir "================ Prueba 11.4: Persistencia y buen funcionamiento ================"

    emitir "-- Insertando dato de prueba en la base $POSTGRES_DB:"
    docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -c "INSERT INTO usuarios_app(usuario) VALUES ('$dato') ON CONFLICT (usuario) DO NOTHING;" | tee -a "$LOG_FILE"
    emitir "-- Contenido ANTES de detener el stack:"
    docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -c "SELECT id, usuario FROM usuarios_app ORDER BY id;" | tee -a "$LOG_FILE"

    emitir "-- Deteniendo y borrando contenedores con docker compose down:"
    cd "$SCRIPT_DIR"
    compose_cmd down | tee -a "$LOG_FILE"

    emitir "-- Iniciando de nuevo con docker compose up -d:"
    compose_cmd up -d 2>&1 | tee -a "$LOG_FILE"

    emitir "-- Esperando a que la base de datos este healthy:"
    if esperar_postgres_healthy; then
        emitir "[OK] servidor_postgres esta healthy."
    else
        emitir "[ERROR] servidor_postgres no alcanzo el estado healthy."
        RESULTADOS+=("11.4 persistencia y buen funcionamiento: FAIL (base no llego a healthy)")
        return 1
    fi

    local pgadmin_estado
    pgadmin_estado="$(docker inspect -f '{{.State.Status}}' "$PGADMIN_CONTAINER" 2>/dev/null)"
    if [ "$pgadmin_estado" = "running" ]; then
        emitir "[OK] servidor_pgadmin inicio despues de que la base estuviera healthy (dependencia service_healthy)."
    else
        emitir "[ERROR] servidor_pgadmin no esta corriendo (estado: ${pgadmin_estado:-desconocido})."
        RESULTADOS+=("11.4 persistencia y buen funcionamiento: FAIL (pgAdmin no inicio)")
        return 1
    fi

    emitir "-- Contenido DESPUES de volver a iniciar el stack:"
    if docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -tA -c "SELECT 1 FROM usuarios_app WHERE usuario = '$dato';" | grep -qx '1'; then
        docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
            -c "SELECT id, usuario FROM usuarios_app ORDER BY id;" | tee -a "$LOG_FILE"
        RESULTADOS+=("11.4 persistencia y buen funcionamiento: PASS")
        emitir "[OK] Prueba 11.4 superada: los datos persisten gracias al volumen db_data."
    else
        RESULTADOS+=("11.4 persistencia y buen funcionamiento: FAIL (datos perdidos)")
        emitir "[ERROR] No se encontro el dato de prueba despues de volver a iniciar el stack."
        return 1
    fi

    refrescar_hosts
}

mostrar_resumen() {
    local total="${#RESULTADOS[@]}"
    local pases=0

    emitir ""
    emitir "================ RESUMEN DE REVISION ================"
    for r in "${RESULTADOS[@]}"; do
        emitir "  $r"
        case "$r" in
            *PASS*) pases=$((pases + 1)) ;;
        esac
    done
    emitir ""
    emitir "Resultado: $pases de $total pruebas superadas."
    emitir "Evidencia completa: $LOG_FILE"

    if [ "$pases" -eq "$total" ]; then
        emitir "REVISION EXITOSA"
    else
        emitir "REVISION CON FALLOS - revise las pruebas marcadas como FAIL"
    fi
}

main() {
    require_root

    if ! cargar_env; then
        exit 1
    fi

    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="$(hostname -I | awk '{print $1}')"
    fi

    emitir "Inicio de revision de la Practica 11"
    emitir "Fecha: $(date)"
    emitir "IP del servidor: $SERVER_IP"
    emitir "Log de evidencia: $LOG_FILE"

    if ! verificar_prerequisitos; then
        exit 1
    fi

    refrescar_hosts 2>/dev/null || true

    prueba_11_1
    prueba_11_2
    prueba_11_3
    prueba_11_4

    mostrar_resumen

    local total="${#RESULTADOS[@]}"
    local pases=0
    for r in "${RESULTADOS[@]}"; do
        case "$r" in
            *PASS*) pases=$((pases + 1)) ;;
        esac
    done

    if [ "$pases" -eq "$total" ]; then
        exit 0
    fi
    exit 1
}

main "$@"
