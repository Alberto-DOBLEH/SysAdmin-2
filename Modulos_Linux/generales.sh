#!/bin/bash

verificar_servicio() {
    servicio=$1

    if dpkg -l | grep -q "$servicio"; then
        echo "true"
    else
        echo "false"
    fi
}