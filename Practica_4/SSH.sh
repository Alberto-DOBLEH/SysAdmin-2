#!/bin/bash
source ../Modulos_Linux/generales.sh
source ../Modulos_Linux/modulos_redes.sh

ip=""
read -p "Introduzca la direcion IP: " ip
asignar_ip_estatica "$ip" 24

verificar_servicio openssh-server

#Solicitud de datos para creacion de usuario
usuario=""
while true; do
  read -p "Introduzca el nombre de usuario: " usuario
  if [[ -n "$usuario" ]]; then
    echo -e "Usuario Valido"
    break
  fi
  echo -e "El usuario no puede estar vacio"
done
contrasena=""
while true; do
  read -p "Introduzca la contrasena: " contrasena
  if [[ -n "$contrasena" ]]; then
    echo -e "Contrasena Valida"
    break
  fi
  echo -e "La contrasena no puede estar vacia"
done

#Crear usuario
echo -e "Creando usuario..."
useradd -m -d /home/$usuario -s /bin/bash $usuario
echo "$usuario:$contrasena" | chpasswd

#Verificar que el usuario fue creado
echo -e "Verificando que el usuario fue creado..."
cat /etc/passwd | grep $usuario

#Asignando permisos para el usuario en el SSH
echo -e "Asignando permisos para el usuario en el SSH..."
path="/home/$usuario/.ssh"
mkdir -p $path
chmod 700 $path
chown $usuario:$usuario $path

#Ajustando Firewall para permitir SSH
echo "Ajustando Firewall para permitir SSH..."
ufw allow ssh

#Iniciando el servicio SSH
echo "Iniciando el servicio SSH..."
systemctl start ssh

echo "Verificando el servicio SSH..."
systemctl status ssh
