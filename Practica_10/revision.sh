#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/Modulos_Linux/contenedores.sh"

WEB_CONTAINER="sysadmin10_web"
DB_CONTAINER="sysadmin10_postgres"
FTP_CONTAINER="sysadmin10_ftp"
NETWORK_NAME="infra_red"
DB_VOLUME="db_data"

POSTGRES_USER="admin"
POSTGRES_PASSWORD="SysAdmin10!"
POSTGRES_DB="usuarios"

FTP_USER="ftpadmin"
FTP_PASSWORD="SysAdmin10!"

SERVER_IP="${1:-}"

LOG_FILE="$SCRIPT_DIR/revision_$(date +%Y%m%d_%H%M%S).log"
RESULTADOS=()

emitir() {
    printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

verificar_prerequisitos() {
    local faltantes=0

    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker no esta instalado. Ejecute primero: sudo bash main.sh"
        return 1
    fi

    for c in "$WEB_CONTAINER" "$DB_CONTAINER" "$FTP_CONTAINER"; do
        if ! docker ps --format '{{.Names}}' | grep -qx "$c"; then
            log_error "El contenedor $c no esta corriendo."
            faltantes=1
        fi
    done

    if [ "$faltantes" -eq 1 ]; then
        log_error "Levante el stack antes de revisar: cd Practica_10 && sudo bash main.sh"
        return 1
    fi

    return 0
}

prueba_10_1() {
    local tabla="revision_persistencia"
    local dato="prueba_persistencia_$(date +%s)"

    emitir ""
    emitir "================ Prueba 10.1: Persistencia de BD ================"

    emitir "-- Creando tabla $tabla y fila de prueba en la base $POSTGRES_DB:"
    docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -c "CREATE TABLE IF NOT EXISTS $tabla (id serial PRIMARY KEY, dato text NOT NULL);" | tee -a "$LOG_FILE"
    docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -c "INSERT INTO $tabla(dato) VALUES ('$dato');" | tee -a "$LOG_FILE"

    emitir "-- Contenido ANTES de eliminar el contenedor:"
    docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -c "SELECT * FROM $tabla;" | tee -a "$LOG_FILE"

    emitir "-- Eliminando contenedor con docker rm -f:"
    docker rm -f "$DB_CONTAINER" | tee -a "$LOG_FILE"

    emitir "-- Recreando contenedor con el mismo volumen $DB_VOLUME:"
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

    if ! esperar_postgres "$DB_CONTAINER" "$POSTGRES_USER"; then
        RESULTADOS+=("10.1 persistencia BD: FAIL (PostgreSQL no inicio despues de recrear)")
        return 1
    fi

    emitir "-- Contenido DESPUES de recrear el contenedor:"
    docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -c "SELECT * FROM $tabla;" | tee -a "$LOG_FILE"

    if docker exec "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA \
        -c "SELECT 1 FROM $tabla WHERE dato = '$dato';" | grep -qx '1'; then
        RESULTADOS+=("10.1 persistencia BD: PASS")
        emitir "[OK] Prueba 10.1 superada: los datos persisten despues de docker rm -f y recrear el contenedor."
    else
        RESULTADOS+=("10.1 persistencia BD: FAIL (los datos no persistieron)")
        emitir "[ERROR] Prueba 10.1 fallada: no se encontro la fila esperada tras recrear el contenedor."
    fi
}

prueba_10_2() {
    emitir ""
    emitir "================ Prueba 10.2: Aislamiento de red ================"
    emitir "-- Ping desde $WEB_CONTAINER al nombre del contenedor $DB_CONTAINER:"

    if docker exec "$WEB_CONTAINER" ping -c 3 "$DB_CONTAINER" 2>&1 | tee -a "$LOG_FILE"; then
        RESULTADOS+=("10.2 aislamiento red: PASS")
        emitir "[OK] Prueba 10.2 superada: el servidor web resuelve y alcanza la base de datos por nombre."
    else
        RESULTADOS+=("10.2 aislamiento red: FAIL")
        emitir "[ERROR] Prueba 10.2 fallada: no hubo respuesta del ping al contenedor de la base de datos."
    fi
}

prueba_10_3() {
    local archivo="revision_p10_$(date +%s).txt"
    local contenido="Archivo de prueba subido por FTP durante la revision de la practica 10"
    local ruta_local="/tmp/$archivo"

    emitir ""
    emitir "================ Prueba 10.3: Permisos FTP y publicacion web ================"

    printf '%s\n' "$contenido" > "$ruta_local"

    emitir "-- Subiendo archivo por FTP a $SERVER_IP/uploads/:"
    if curl -sS -f -T "$ruta_local" "ftp://$SERVER_IP/uploads/$archivo" --user "$FTP_USER:$FTP_PASSWORD" | tee -a "$LOG_FILE"; then
        emitir "[OK] Archivo subido correctamente por FTP."
    else
        emitir "[ERROR] No se pudo subir el archivo por FTP."
        RESULTADOS+=("10.3 permisos FTP y web: FAIL (fallo la subida FTP)")
        rm -f "$ruta_local"
        return 1
    fi

    emitir "-- Contenido servido por el servidor web (http://localhost:8080/uploads/$archivo):"
    local obtenido
    obtenido="$(curl -s "http://localhost:8080/uploads/$archivo")"
    emitir "$obtenido"

    if [ "$obtenido" = "$contenido" ]; then
        RESULTADOS+=("10.3 permisos FTP y web: PASS")
        emitir "[OK] Prueba 10.3 superada: el archivo subido por FTP es visible por el servidor web."
    else
        RESULTADOS+=("10.3 permisos FTP y web: FAIL (el contenido no es visible por web)")
        emitir "[ERROR] El servidor web no devolvio el contenido esperado."
    fi

    emitir "-- Limpiando archivo de prueba:"
    curl -sS -Q "DELE uploads/$archivo" "ftp://$SERVER_IP/" --user "$FTP_USER:$FTP_PASSWORD" >/dev/null 2>&1 || true
    rm -f "$ruta_local"
    emitir "[OK] Archivo de prueba eliminado."
}

prueba_10_4() {
    emitir ""
    emitir "================ Prueba 10.4: Limites de recursos ================"
    emitir "-- docker stats --no-stream:"

    local stats
    stats="$(docker stats --no-stream \
        --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}\t{{.PIDs}}" \
        "$WEB_CONTAINER" "$DB_CONTAINER" "$FTP_CONTAINER" 2>&1)"
    emitir "$stats"

    local limite_ok=1
    for c in "$WEB_CONTAINER" "$DB_CONTAINER" "$FTP_CONTAINER"; do
        if ! echo "$stats" | grep -q "${c}.*/ 512MiB"; then
            emitir "[ERROR] $c no muestra el limite de memoria de 512MiB."
            limite_ok=0
        fi
    done

    if [ "$limite_ok" -eq 1 ]; then
        RESULTADOS+=("10.4 limites de recursos: PASS")
        emitir "[OK] Prueba 10.4 superada: los tres contenedores muestran limite de memoria de 512MiB."
    else
        RESULTADOS+=("10.4 limites de recursos: FAIL")
        emitir "[ERROR] Prueba 10.4 fallada: al menos un contenedor no muestra el limite de memoria esperado."
    fi
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

    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="$(hostname -I | awk '{print $1}')"
    fi

    emitir "Inicio de revision de la Practica 10"
    emitir "Fecha: $(date)"
    emitir "IP del servidor usada para FTP: $SERVER_IP"
    emitir "Log de evidencia: $LOG_FILE"

    if ! verificar_prerequisitos; then
        exit 1
    fi

    prueba_10_1
    prueba_10_2
    prueba_10_3
    prueba_10_4

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
