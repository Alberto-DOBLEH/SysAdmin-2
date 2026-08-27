#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/Modulos_Linux/contenedores.sh"

ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

MAIL_CONTAINER="mailserver"
DB_CONTAINER="roundcube-db"
WEBMAIL_CONTAINER="roundcubemail"

WEBMAIL_PORT=8081
MAIL_PORTS="25 143 587 993"

CUENTAS_ESPERADAS="director admin kami goku vegeta"
LOG_DIR="$SCRIPT_DIR/logs"

SERVER_IP="${1:-}"

LOG_FILE="$SCRIPT_DIR/revision_$(date +%Y%m%d_%H%M%S).log"
RESULTADOS=()

emitir() {
    printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

cargar_env() {
    if [ ! -f "$ENV_FILE" ]; then
        log_error "No existe $ENV_FILE. Ejecute primero: cd Practica_12 && sudo bash main.sh"
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

    for c in "$MAIL_CONTAINER" "$DB_CONTAINER" "$WEBMAIL_CONTAINER"; do
        if ! docker ps --format '{{.Names}}' | grep -qx "$c"; then
            log_error "El contenedor $c no esta corriendo."
            faltantes=1
        fi
    done

    if [ "$faltantes" -eq 1 ]; then
        log_error "Levante el stack antes de revisar: cd Practica_12 && sudo bash main.sh"
        return 1
    fi

    return 0
}

esperar_roundcube_db_healthy() {
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

prueba_12_1() {
    local ok=1

    emitir ""
    emitir "================ Prueba 12.1: Stack de correo activo ================"

    if ! esperar_roundcube_db_healthy; then
        emitir "[ERROR] $DB_CONTAINER no alcanzo el estado healthy."
        ok=0
    else
        emitir "[OK] $DB_CONTAINER esta healthy."
    fi

    for c in "$MAIL_CONTAINER" "$DB_CONTAINER" "$WEBMAIL_CONTAINER"; do
        estado="$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null)"
        if [ "$estado" = "running" ]; then
            emitir "[OK] Contenedor $c en estado running."
        else
            emitir "[ERROR] Contenedor $c en estado ${estado:-desconocido}."
            ok=0
        fi
    done

    if [ "$ok" -eq 1 ]; then
        RESULTADOS+=("12.1 stack activo: PASS")
        emitir "[OK] Prueba 12.1 superada: los tres contenedores estan activos."
    else
        RESULTADOS+=("12.1 stack activo: FAIL")
        emitir "[ERROR] Prueba 12.1 fallada."
    fi
}

prueba_12_2() {
    local ok=1

    emitir ""
    emitir "================ Prueba 12.2: Puertos de correo y webmail ================"

    for puerto in $MAIL_PORTS $WEBMAIL_PORT; do
        if nc -z 127.0.0.1 "$puerto" >/dev/null 2>&1; then
            emitir "[OK] Puerto $puerto respondiendo."
        else
            emitir "[ERROR] Puerto $puerto no responde."
            ok=0
        fi
    done

    if [ "$ok" -eq 1 ]; then
        RESULTADOS+=("12.2 puertos: PASS")
        emitir "[OK] Prueba 12.2 superada: SMTP/IMAP y webmail expuestos correctamente."
    else
        RESULTADOS+=("12.2 puertos: FAIL")
        emitir "[ERROR] Prueba 12.2 fallada: algun puerto no responde."
    fi
}

prueba_12_3() {
    local ok=1
    local listado

    emitir ""
    emitir "================ Prueba 12.3: Cuentas de correo ================"

    listado="$(docker exec "$MAIL_CONTAINER" setup email list 2>&1 | tee -a "$LOG_FILE")"

    for cuenta in $CUENTAS_ESPERADAS; do
        if echo "$listado" | grep -q "$cuenta@${DOMAIN}"; then
            emitir "[OK] Cuenta $cuenta@${DOMAIN} encontrada."
        else
            emitir "[ERROR] Falta la cuenta $cuenta@${DOMAIN}."
            ok=0
        fi
    done

    if [ "$ok" -eq 1 ]; then
        RESULTADOS+=("12.3 cuentas de correo: PASS")
        emitir "[OK] Prueba 12.3 superada: las cinco cuentas preconfiguradas existen."
    else
        RESULTADOS+=("12.3 cuentas de correo: FAIL")
        emitir "[ERROR] Prueba 12.3 fallada: faltan cuentas en postfix-accounts.cf."
    fi
}

prueba_12_4() {
    local ok=1
    local codigo
    local destinatario="vegeta@${DOMAIN}"

    emitir ""
    emitir "================ Prueba 12.4: Envio, recepcion y webmail ================"

    emitir "-- Enviando correo de prueba desde el propio mailserver a $destinatario:"
    docker exec "$MAIL_CONTAINER" bash -c 'echo "Subject: Prueba Practica 12" | sendmail -v '"$destinatario" | tee -a "$LOG_FILE"

    emitir "-- Buscando confirmacion de entrega en el log de correo:"
    local encontrado=0
    for _ in $(seq 1 30); do
        if grep -q "to=<$destinatario>.*status=sent" "$LOG_DIR/mail.log" 2>/dev/null; then
            encontrado=1
            break
        fi
        sleep 2
    done

    if [ "$encontrado" -eq 1 ]; then
        emitir "[OK] Entrega confirmada: status=sent hacia $destinatario."
    else
        emitir "[ERROR] No se encontro status=sent hacia $destinatario en $LOG_DIR/mail.log."
        ok=0
    fi

    emitir "-- Verificando que el webmail responde en el puerto $WEBMAIL_PORT:"
    codigo="$(curl --max-time 10 -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${WEBMAIL_PORT}")"
    if [ "$codigo" = "200" ] || [ "$codigo" = "302" ] || [ "$codigo" = "301" ]; then
        emitir "[OK] Roundcube responde con HTTP $codigo."
    else
        emitir "[ERROR] Roundcube respondio con HTTP $codigo (se esperaba 200/301/302)."
        ok=0
    fi

    if [ "$ok" -eq 1 ]; then
        RESULTADOS+=("12.4 envio/recepcion y webmail: PASS")
        emitir "[OK] Prueba 12.4 superada: el correo se entrega y el webmail responde."
    else
        RESULTADOS+=("12.4 envio/recepcion y webmail: FAIL")
        emitir "[ERROR] Prueba 12.4 fallada."
    fi
}

prueba_12_5() {
    emitir ""
    emitir "================ Prueba 12.5: DKIM (informativo) ================"

    if [ -f "$SCRIPT_DIR/config/opendkim/keys/${DOMAIN}/mail.private" ]; then
        emitir "[OK] Clave privada DKIM de ${DOMAIN} presente en la configuracion."
    else
        emitir "[ERROR] Falta la clave privada DKIM de ${DOMAIN}."
    fi

    emitir "-- Comprobando firma DKIM local (sin DNS externo es normal 'key not secure'):"
    docker exec "$MAIL_CONTAINER" opendkim-testkey -d "$DOMAIN" -s mail -vvv | tee -a "$LOG_FILE"
    emitir "[INFO] Prueba 12.5 informativa: confirme la firma con un DNS publico si desea."
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

    emitir "Inicio de revision de la Practica 12"
    emitir "Fecha: $(date)"
    emitir "IP del servidor: $SERVER_IP"
    emitir "Log de evidencia: $LOG_FILE"

    if ! verificar_prerequisitos; then
        exit 1
    fi

    prueba_12_1
    prueba_12_2
    prueba_12_3
    prueba_12_4
    prueba_12_5

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