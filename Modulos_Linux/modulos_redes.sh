#!/bin/bash

verificar_formato_ip() {
    ip=$1
    regex='^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])$'

    if [[ $ip =~ $regex ]]; then
        return 0
    else
        return 1
    fi
}

asignar_ip_estatica() {

    INTERFAZ="ensp0s8"  # Cambia si es necesario

    dhcp=$(nmcli -g ipv4.method connection show "$INTERFAZ" 2>/dev/null)

    if [ "$dhcp" = "auto" ]; then
        echo -e "\e[33mLa IP es dinámica.\e[0m"

        while true; do
            read -p "Ingrese la IP que quiere para el servidor: " ipserver
            if verificar_formato_ip "$ipserver"; then
                echo -e "\e[32mLa IP es valida\e[0m"
                break
            else
                echo -e "\e[31mIP no valida\e[0m"
            fi
        done

        echo "Asignando IP estatica..."
        sudo nmcli connection modify "$INTERFAZ" ipv4.addresses "$ipserver/24"
        sudo nmcli connection modify "$INTERFAZ" ipv4.method manual
        sudo nmcli connection up "$INTERFAZ"

    else
        echo "La IP ya es estatica."
    fi
}

obtener_segmento() {
    IFS='.' read -r o1 o2 o3 o4 <<< "$1"
    echo "$o1.$o2.$o3.0"
}

verificar_segmento() {
    IFS='.' read -r ip1 ip2 ip3 ip4 <<< "$1"
    IFS='.' read -r s1 s2 s3 s4 <<< "$2"

    if [[ "$ip1" == "$s1" && "$ip2" == "$s2" && "$ip3" == "$s3" ]]; then
        return 0
    else
        return 1
    fi
}