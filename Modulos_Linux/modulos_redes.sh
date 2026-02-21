#!/bin/bash

asignar_ip_estatica() {

    INTERFAZ="enp0s8"
    IP="$1"
    CIDR="$2"

    # Validar que la interfaz exista
    if ! ip link show "$INTERFAZ" &> /dev/null; then
        echo "La interfaz $INTERFAZ no existe."
        return 1
    fi

    # Validar formato de IP
    regex_ip='^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])$'
    if [[ ! $IP =~ $regex_ip ]]; then
        echo "Formato de IP inválido."
        return 1
    fi

    # Validar CIDR (0-32)
    if ! [[ "$CIDR" =~ ^([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
        echo "CIDR inválido (debe ser entre 0 y 32)."
        return 1
    fi

    echo "Configurando IP estática $IP/$CIDR en $INTERFAZ..."

    ip addr flush dev "$INTERFAZ"
    ip addr add "$IP/$CIDR" dev "$INTERFAZ"
    ip link set "$INTERFAZ" up

    echo "Configuración aplicada correctamente."
}