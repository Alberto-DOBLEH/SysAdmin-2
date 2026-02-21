#!/bin/bash

asignar_ip_estatica() {

    IP="$1"
echo -e "Empezando la insercion de nueva informacion al archivo.."
cat << EOF | sudo tee /etc/netplan/50-cloud-init.yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true

    enp0s8:
      dhcp4: false
      addresses:
        - ${IP}/24
      gateway4: ${IP}
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF

    # Aplicar cambios
    echo -e "Aplicando cambios en los adaptadores de red de la maquina...."
    sudo netplan apply

    echo "Configuración aplicada correctamente."
}