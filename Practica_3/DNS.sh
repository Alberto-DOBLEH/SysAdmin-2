#!/bin/bash

# ===== Importacion de modulos =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULOS_PATH="$SCRIPT_DIR/../Modulos_Linux"

source "$MODULOS_PATH/modulos_redes.sh"
source "$MODULOS_PATH/generales.sh"

if networkctl status enp0s8 | grep -q "DHCP4"; then
    asignar_ip_estatica
else
    echo "IP estatica"
fi

servicio="bind9"
validacion=$(verificar_servicio "$servicio")

if [ "$validacion" = "true" ]; then
    echo -e "\e[32mEl servicio DNS ya esta instalado\e[0m"
else
    echo "Servicio DNS no esta instalado"
    echo "Empezando proceso de instalacion.."
    sudo apt update
    sudo apt install -y bind9 bind9utils bind9-doc
fi

iteracion=true

while [ "$iteracion" = true ]; do

    # ===== Dominio =====
    while true; do
        read -p "Ingrese el dominio deseado en terminacion.com: " dominio

        if [[ -z "$dominio" ]]; then
            echo -e "\e[31mDominio no puede ser vacio\e[0m"
        elif [[ "$dominio" =~ \.com$ ]]; then
            echo -e "\e[32mDominio Valido\e[0m"
            break
        else
            echo -e "\e[31mDominio invalido, debe terminar en .com\e[0m"
        fi
    done

    # ===== IP =====
    while true; do
        read -p "Ingrese la direccion IP que se va apuntar: " ip
        if verificar_formato_ip "$ip"; then
            break
        else
            echo -e "\e[31mIP no valida\e[0m"
        fi
    done

    # ===== Crear zona =====
    ZONE_FILE="/etc/bind/db.$dominio"

    sudo bash -c "cat > $ZONE_FILE" <<EOF
\$TTL 604800
@   IN  SOA ns.$dominio. admin.$dominio. (
        2
        604800
        86400
        2419200
        604800 )
@       IN  NS      ns.$dominio.
@       IN  A       $ip
www     IN  A       $ip
ns      IN  A       $ip
EOF

    sudo bash -c "echo 'zone \"$dominio\" { type master; file \"$ZONE_FILE\"; };' >> /etc/bind/named.conf.local"

    echo -e "\e[32mSe registro la Primary Zone del dominio: $dominio\e[0m"
    echo -e "\e[32mSe generaron los registros\e[0m"
    echo "Dominio configurado con exito"

    while true; do
        read -p "Quiere registrar otro dominio (S/N): " res
        res=$(echo "$res" | tr '[:upper:]' '[:lower:]')

        case $res in
            s) break ;;
            n)
                iteracion=false
                break
                ;;
            *)
                echo -e "\e[31mFavor de ingresar una opcion valida\e[0m"
                ;;
        esac
    done

done

echo "Reiniciando el servicio DNS"
sudo systemctl restart bind9
echo "Servicio reestablecido"