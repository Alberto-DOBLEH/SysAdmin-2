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

    read -p "Ingrese la ip para el servidor: " ipserver

    echo -e "${color}Empezando proceso de asignacion de ip estatica a la red local.....${reset}"
    echo -e "${color}Generando copia de seguridad del archivo de configuracion de NetPlan....${reset}"
    sudo cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.bak  # Copia de seguridad

    echo -e "${color}Empezando la insercion de nueva informacion al archivo..${reset}"
    cat << EOF | sudo tee /etc/netplan/50-cloud-init.yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true

    enp0s8:
      dhcp4: false
      addresses:
        - ${ipserver}/24
      gateway4: ${ipserver}
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF

    # Aplicar cambios
    echo -e "${color}Aplicando cambios en los adaptadores de red de la maquina....${reset}"
    sudo netplan apply

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