#!/bin/bash

verificar_servicio () {
    if ! dpkg -s "$1" &> /dev/null; then
        echo "Instalando $1..."
        apt update -y
        apt install -y "$1" "$2" "$3"
    else
        echo "$1 ya está instalado."
    fi
}