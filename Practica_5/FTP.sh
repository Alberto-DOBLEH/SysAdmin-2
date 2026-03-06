#!/bin/bash
source ../Modulos_Linux/usuarios.sh

#Verificar si esta instalado el servicio
conf=""
servicio="vsftpd"
if command -v "$servicio" &> /dev/null; then
    echo "El servicio FTP está instalado."
    conf="ei"
else
    echo "El servicio FTP no está instalado."
    #Actualizando el sistema
    apt-get update -y
    apt-get upgrade -y

    #Instalando el servidor FTP
    apt-get install vsftpd -y
    conf="nel"
fi

if [[ "$conf" == "nel" ]]; then
    echo "Entrando a configuraciones..."
    #Seccion archivo de vsftpd
    echo "Configurando vsftpd..."

    conf_file="/etc/vsftpd.conf"
    backup_file="/etc/vsftpd.conf.bak"
    # Realizar backup del archivo original
    sudo cp "$conf_file" "$backup_file"
    echo "Backup realizado en $backup_file"

    # Escribir la configuración básica recomendada
    sudo bash -c "cat > $conf_file" <<EOF
# vsftpd.conf - Configuración de vsftpd para Ubuntu Server FTP

listen=YES
listen_ipv6=NO

# Habilitar acceso anónimo y establecer directorio raíz para anónimos
anonymous_enable=YES
anon_root=/srv/ftp/LocalUser/Public

# Habilitar usuarios locales
local_enable=YES
write_enable=YES

# Seguridad y chroot (se mantiene para que cada usuario vea solo su jail)
chroot_local_user=YES
allow_writeable_chroot=YES

# Mensajes, logs y transferencias
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES

# Configuración del modo pasivo
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000

# Opcional: Lista de usuarios permitidos
#userlist_enable=YES
#userlist_deny=NO
#userlist_file=/etc/vsftpd.user_list
EOF

    echo "Archivo vsftpd.conf configurado correctamente."

    #Generacion de carpetas
    carpeta_raiz="/srv/ftp"
    carpetas_base=(
        "$carpeta_raiz/LocalUser/Public"
        "$carpeta_raiz/reprobados"
        "$carpeta_raiz/recursadores"
    )

    echo "Configurando carpetas base del FTP..."

    # Crear carpeta principal si no existe
    if [ ! -d "$carpeta_raiz" ]; then
        sudo mkdir -p "$carpeta_raiz"
        echo "Carpeta principal '$carpeta_raiz' creada."
    else
        echo "Carpeta principal '$carpeta_raiz' ya existe."
    fi

    # Asegurar la existencia de la carpeta para usuarios locales
    if [ ! -d "$carpeta_raiz/LocalUser" ]; then
        sudo mkdir -p "$carpeta_raiz/LocalUser"
        echo "Carpeta 'LocalUser' creada."
    fi

    # Crear las carpetas base
    for carpeta in "${carpetas_base[@]}"; do
        if [ ! -d "$carpeta" ]; then
            sudo mkdir -p "$carpeta"
            echo "Carpeta '$carpeta' creada."
        else
            echo "Carpeta '$carpeta' ya existe."
        fi
    done
    echo "Carpetas base configuradas exitosamente."
    

    #Generacion de grupos
    grupos=("reprobados" "recursadores")
    echo "Creando grupos locales de Linux para FTP..."

    for group_name in "${grupos[@]}"; do
        if ! getent group "$group_name" > /dev/null; then
            sudo groupadd "$group_name"
            if [ $? -eq 0 ]; then
                echo "Grupo '$group_name' creado exitosamente."
            else
                echo "Error al crear el grupo '$group_name'. Deteniendo el script."
                exit 1
            fi
        else
            echo "El grupo '$group_name' ya existe."
        fi
    done
    echo "Grupos locales creados exitosamente."

    #Cronfiguracion del acceso a anonimos
    carpeta_publica="/srv/ftp/LocalUser/Public"
    echo "Configurando acceso anónimo a la carpeta '$carpeta_publica'..."

    # Permisos de solo lectura para usuarios anónimos
    sudo chmod 0555 "$carpeta_publica"
    echo "Permisos de lectura configurados en '$carpeta_publica'."

    # Habilitar acceso anónimo en vsftpd.conf (si se encuentra comentado)
    config_file="/etc/vsftpd.conf"
    sudo sed -i 's/^#anon_enable=YES/anon_enable=YES/' "$config_file"

    echo "Acceso anónimo habilitado en vsftpd.conf."

    #Asignacion de permisos de grupos y usuarios
    carpeta_raiz_ftp="/srv/ftp"
    carpeta_publica="$carpeta_raiz_ftp/LocalUser/Public"
    carpeta_reprobados="$carpeta_raiz_ftp/reprobados"
    carpeta_recursadores="$carpeta_raiz_ftp/recursadores"

    echo "Configurando permisos para la carpeta '$carpeta_publica'..."
    sudo chmod 0755 "$carpeta_publica"
    echo "Permisos configurados en '$carpeta_publica'."

    echo "Configurando permisos para la carpeta '$carpeta_reprobados'..."
    sudo chmod 0770 "$carpeta_reprobados"
    sudo chown root:reprobados "$carpeta_reprobados"
    echo "Permisos configurados para el grupo 'reprobados'."

    echo "Configurando permisos para la carpeta '$carpeta_recursadores'..."
    sudo chmod 0770 "$carpeta_recursadores"
    sudo chown root:recursadores "$carpeta_recursadores"
    echo "Permisos configurados para el grupo 'recursadores'."

    echo "Configurando permisos en la raíz '$carpeta_raiz_ftp'..."
    sudo chmod 0755 "$carpeta_raiz_ftp"
    echo "Permisos de listado y recorrido en la raíz configurados."

    echo "Permisos para grupos y usuarios autenticados configurados exitosamente."

    #Reiniciando el servidor FTP
    systemctl restart vsftpd

    #Mostrando el servicio corriendo
    systemctl status vsftpd
fi
while true;do
    echo "--Gestor de usuarios--"
    echo "[1].-Crear Usuario"
    echo "[2].-Eliminar Usuario"
    echo "[3].-Cambiar de grupo"
    echo "[4].-Salir"
    read -p "Elija una opcion: " opc

    case "$opc" in
        1)
            crear_usuario
            sudo systemctl restart vsftpd
            ;;
        2)
            eliminar_usuario
            sudo systemctl restart vsftpd
            ;;
        3)
            editar_grupo
            sudo systemctl restart vsftpd
            ;;
        4)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Escoja una opcion valida(1 al 4)"
            ;;
    esac
done