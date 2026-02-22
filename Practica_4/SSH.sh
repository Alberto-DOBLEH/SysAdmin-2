#!/bin/bash
source ../Modulos_Linux/generales.sh
source ../Modulos_Linux/modulos_redes.sh

ip=""
read -p "Introduzca la direcion IP: " ip
asignar_ip_estatica "$ip" 24

verificar_servicio openssh-server

#Ajustando Firewall para permitir SSH
echo "Ajustando Firewall para permitir SSH..."
ufw allow ssh

#Iniciando el servicio SSH
echo "Iniciando el servicio SSH..."
systemctl start ssh

echo "Verificando el servicio SSH..."
systemctl status ssh
