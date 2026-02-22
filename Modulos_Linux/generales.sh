#!/bin/bash

verificar_servicio () {
    for paquete in "$@"; do
        if ! dpkg -s "$paquete" &> /dev/null; then
            echo "Instalando $paquete..."
            apt update -y
            apt install -y "$paquete"
        else
            echo "$paquete ya está instalado."
        fi
    done
}