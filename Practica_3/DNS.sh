#!/bin/bash
source ../Modulos_Linux/generales.sh
source ../Modulos_Linux/modulos_redes.sh


ip=""
read -p "Introduzca la direcion IP: " ip
asignar_ip_estatica "$ip" 24

verificar_servicio bind9 bind9utils bind9-doc

echo "Creando carpeta de zonas..."
sudo mkdir -p /etc/bind/zones
sudo chown bind:bind /etc/bind/zones

while true; do

    # Dominio
    while true; do
        read -p "Introduzca el dominio: " dominio
        if [[ -n "$dominio" ]]; then
            echo "Dominio Valido"
            break
        fi
        echo "El dominio no puede estar vacio"
    done

    # IP
    read -p "Introduzca la direccion IP: " ip

    nombrearchzona="db.${dominio}"
    ruta="/etc/bind/zones/${nombrearchzona}"

    echo "Generando la zona del dominio...."

    sudo tee "${ruta}" > /dev/null << EOF
\$TTL 86400
@   IN  SOA ns1.${dominio}. admin.${dominio}. (
        $(date +%Y%m%d)01 ; Serial
        28800       ; Refresh
        7200        ; Retry
        864000      ; Expire
        86400 )     ; Minimum TTL
;
    IN  NS  ns1.${dominio}.
ns1 IN  A   ${ip}
@   IN  A   ${ip}
www IN  A   ${ip}
EOF

    sudo chown bind:bind "${ruta}"

    echo "Configurando la zona en named.conf.local..."

    ZoneConfig="/etc/bind/named.conf.local"

    # Evitar duplicados
    if ! grep -q "zone \"${dominio}\"" "$ZoneConfig"; then
        echo "zone \"${dominio}\" {
    type master;
    file \"${ruta}\";
};" | sudo tee -a "$ZoneConfig" > /dev/null
    else
        echo "La zona ya existe en named.conf.local"
    fi

    echo "Verificacion final..."
    sudo named-checkconf

    if [ $? -eq 0 ]; then
        echo "Configuracion valida"
    else
        echo "Error en la configuracion"
    fi

    # Preguntar si quiere agregar otro dominio
    while true; do
        read -p "¿Desea agregar otro dominio? (S/N): " respuesta
        respuesta=$(echo "$respuesta" | tr '[:upper:]' '[:lower:]')

        case $respuesta in
            s) break ;;
            n)
                echo "Reiniciando servicio bind9..."
                sudo systemctl restart bind9
                echo "Proceso finalizado."
                exit 0
                ;;
            *)
                echo "Opcion invalida"
                ;;
        esac
    done

done