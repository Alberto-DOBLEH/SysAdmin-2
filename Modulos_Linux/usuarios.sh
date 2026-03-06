DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VALIDADORES="$DIR/validadores.sh"
source "$VALIDADORES"

crear_usuario() {

    #Faltan validaciones
    while true; do
        read -p "Ingrese el nombre de usuario: " username
        if ! validar_textos_nulos "$username"; then
            echo "Error: El usuario no puede ser vacio"
            continue
        fi
        if [[ "$username" =~ [0-9] ]]; then
            echo "Error: El usuario no puede tener numeros"
            continue
        fi
        if ! validar_espacios "$username"; then
            echo "Error: El usuario no puede contener espacios"
            continue
        fi
        if ! validar_longitud_maxima "$username"; then
            echo "Error: EL usuario no puede ser mayor a 20 caracteres"
            continue
        fi
        if ! validar_sin_caracteres_especiales "$username"; then
            echo "Error: El usuario no puede contener caracteres especiales"
            continue
        fi
        if validar_usuario_existente "$username"; then
            echo "Error: El usuario ya existe"
            continue
        fi

        echo "Usuario válido."
        break
    done
    while true; do
        read -s -p "Ingrese la contraseña: " password
        echo
        if ! validar_textos_nulos "$password"; then
            echo "Error: El usuario no puede ser vacio"
            continue
        fi
        if ! validar_espacios "$password"; then
            echo "Error: El usuario no puede contener espacios"
            continue
        fi
        if ! validar_contrasena "$password" "$usuario"; then
            echo "La contraseña no cuenta con el formato(8 a 12 caracteres, una mayuscula, un numero y no tener el nombre del usuario)"
            continue
        fi

        echo "Contraseña Valida"
        break
    done
    

    while true; do
        echo "Seleccione el grupo de usuario:"
        echo "[1].-reprobados"
        echo "[2].-recursadores"
        read -p "Elija una opcion: " grupo_opcion
        case "$grupo_opcion" in
            1) group_name="reprobados"; break ;;
            2) group_name="recursadores"; break ;;
            *) echo "Opción no válida. Elija 1 o 2."; continue ;;
        esac
    done

    # Crear usuario local con directorio home en /srv/ftp/LocalUser/$username
    echo "Creando usuario...."
    sudo adduser --quiet --disabled-password --home "/srv/ftp/LocalUser/$username" --gecos "" "$username"
    if [ $? -ne 0 ]; then
        echo "Error al crear el usuario '$username'. Revise los errores e intente nuevamente."
        return 1
    fi
    echo "Usuario creado exitosamente."

    # Establecer contraseña del usuario
    echo "Estableciendo contraseña del usuario..."
    echo "$username:$password" | sudo chpasswd
    if [ $? -ne 0 ]; then
        echo "Error al establecer la contraseña para '$username'."
        sudo userdel "$username"
        return 1
    fi
    echo "Contraseña establecida."

    # Añadir usuario al grupo seleccionado
    echo "Añadiendo usuario al grupo '$group_name'..."
    sudo usermod -a -G "$group_name" "$username"
    if [ $? -ne 0 ]; then
        echo "Error al añadir el usuario '$username' al grupo '$group_name'."
        sudo userdel "$username"
        return 1
    fi
    echo "Usuario '$username' añadido al grupo '$group_name'."

    # Directorio home del usuario (ya creado por adduser)
    carpeta_personal_usuario="/srv/ftp/LocalUser/$username"

    #Creando las carpetas dentro del jail
    echo "Creando directorios internos en el home del usuario..."
    sudo mkdir -p "$carpeta_personal_usuario/Public"
    sudo mkdir -p "$carpeta_personal_usuario/$group_name"
    sudo mkdir -p "$carpeta_personal_usuario/$username"

    # Realizar montajes bind para reflejar las carpetas compartidas dentro del jail
    # Montar la carpeta Public compartida
    if mountpoint -q "$carpeta_personal_usuario/Public"; then
        echo "La carpeta Public ya está montada en el jail de '$username'."
    else
        sudo mount --bind /srv/ftp/LocalUser/Public "$carpeta_personal_usuario/Public"
        echo "Montaje bind realizado: /srv/ftp/LocalUser/Public -> $carpeta_personal_usuario/Public"
    fi

    # Montar la carpeta de grupo compartida
    if mountpoint -q "$carpeta_personal_usuario/$group_name"; then
        echo "La carpeta del grupo ya está montada en el jail de '$username'."
    else
        sudo mount --bind "/srv/ftp/$group_name" "$carpeta_personal_usuario/$group_name"
        echo "Montaje bind realizado: /srv/ftp/$group_name -> $carpeta_personal_usuario/$group_name"
    fi

    # Establecer propietario y permisos en el directorio home y subdirectorios
    sudo chown -R "$username":"$username" "$carpeta_personal_usuario"
    sudo chmod 700 "$carpeta_personal_usuario"

    echo "Usuario FTP '$username' creado y configurado exitosamente con acceso a:"
    echo " - Carpeta Public (compartida)"
    echo " - Carpeta del grupo '$group_name'"
    echo " - Carpeta privada: '$username'"
}
eliminar_usuario() {
    while true; do
        read -p "Ingrese el nombre del usuario a eliminar: " username
        if ! validar_textos_nulos "$username"; then
            echo "Error: No hay usuarios vacios"
            continue
        fi
        if ! validar_espacios "$username"; then
            echo "Error: Los usuarios no tiene espacios"
            continue
        fi
        if ! validar_longitud_maxima "$username"; then
            echo "Error: Los usuarios no son mayores de 20 caracteres"
            continue
        fi
        if ! validar_sin_caracteres_especiales "$username"; then
            echo "Error: Los usuarios no contienen caracteres especiales"
            continue
        fi
        if ! validar_usuario_existente "$username"; then
            echo "Error: El usuario no existe"
            continue
        fi

        echo "Usuario válido."
        break
    done

    # Eliminar la carpeta personal del usuario
    carpeta_personal_usuario="/srv/ftp/LocalUser/$username"
    if [ -d "$carpeta_personal_usuario" ]; then
        echo "Eliminando carpeta personal '$carpeta_personal_usuario' de '$username'..."
        sudo umount "$carpeta_personal_usuario/Public" 2>/dev/null
        sudo umount "$carpeta_personal_usuario/$group_name" 2>/dev/null
        sudo rm -rf "$carpeta_personal_usuario"
        if [ $? -eq 0 ]; then
            echo "Carpeta personal eliminada."
        else
            echo "Error al eliminar la carpeta personal."
        fi
    fi

    # Eliminar usuario local de Linux
    echo "Eliminando usuario local '$username'..."
    sudo userdel -r "$username"
    if [ $? -eq 0 ]; then
        echo "Usuario '$username' eliminado exitosamente."
    else
        echo "Error al eliminar el usuario '$username'."
    fi
}
editar_grupo() {
    while true; do
        read -p "Ingrese el nombre del usuario que quiere cambiar de grupo: " username
        if ! validar_textos_nulos "$username"; then
            echo "Error: No hay usuarios vacios"
            continue
        fi
        if ! validar_espacios "$username"; then
            echo "Error: Los usuarios no tiene espacios"
            continue
        fi
        if ! validar_longitud_maxima "$username"; then
            echo "Error: Los usuarios no son mayores de 20 caracteres"
            continue
        fi
        if ! validar_sin_caracteres_especiales "$username"; then
            echo "Error: Los usuarios no contienen caracteres especiales"
            continue
        fi
        if ! validar_usuario_existente "$username"; then
            echo "Error: El usuario no existe"
            continue
        fi

        echo "Usuario válido."
        break
    done

    # Obtener el grupo actual (se asume pertenencia a 'reprobados' o 'recursadores')
    grupo_actual=$(groups "$username" | sed 's/.*: //')
    grupo_actual=$(echo "$grupo_actual" | awk '{for(i=1;i<=NF;i++){if($i=="reprobados" || $i=="recursadores"){print $i; exit}}}')

    if [ -z "$grupo_actual" ]; then
        echo "El usuario '$username' no pertenece a ningún grupo FTP ('reprobados' o 'recursadores')."
        return 1
    fi

    # Seleccionar el nuevo grupo
    while true; do
        echo "Grupo actual del usuario '$username': '$grupo_actual'"
        echo "Seleccione el nuevo grupo de usuario:"
        echo "1. reprobados"
        echo "2. recursadores"
        read -p "Opción (1 o 2): " nuevo_grupo_opcion
        case "$nuevo_grupo_opcion" in
            1) nuevo_grupo_name="reprobados"; break ;;
            2) nuevo_grupo_name="recursadores"; break ;;
            *) echo "Opción no válida. Elija 1 o 2."; continue ;;
        esac
    done

    if [ "$nuevo_grupo_name" == "$grupo_actual" ]; then
        echo "El usuario ya está en el grupo '$grupo_actual'. No se realizarán cambios."
        return 0
    fi

    # Remover usuario del grupo actual
    echo "Removiendo usuario '$username' del grupo '$grupo_actual'..."
    sudo deluser "$username" "$grupo_actual"
    if [ $? -ne 0 ]; then
        echo "Error al remover al usuario del grupo '$grupo_actual'."
        return 1
    fi
    echo "Usuario removido del grupo '$grupo_actual'."

    # Desmontar y eliminar el montaje bind del grupo anterior en el jail del usuario
    old_mount_point="/srv/ftp/LocalUser/${username}/${grupo_actual}"
    if mountpoint -q "$old_mount_point"; then
        echo "Desmontando carpeta del grupo anterior: $old_mount_point"
        sudo umount "$old_mount_point"
    fi
    # Si existía físicamente la carpeta, la borramos
    if [ -d "$old_mount_point" ]; then
        echo "Eliminando directorio del grupo anterior: $old_mount_point"
        sudo rm -rf "$old_mount_point"
    fi

    # Añadir usuario al nuevo grupo
    echo "Añadiendo usuario '$username' al grupo '$nuevo_grupo_name'..."
    sudo usermod -a -G "$nuevo_grupo_name" "$username"
    if [ $? -ne 0 ]; then
        echo "Error al añadir al usuario al grupo '$nuevo_grupo_name'. Reinserción en el grupo anterior..."
        sudo usermod -a -G "$grupo_actual" "$username"
        return 1
    fi
    echo "Usuario añadido al grupo '$nuevo_grupo_name'."

    # Crear el punto de montaje para el nuevo grupo dentro del jail del usuario
    new_mount_point="/srv/ftp/LocalUser/${username}/${nuevo_grupo_name}"
    echo "Creando (o verificando) el directorio de montaje: $new_mount_point"
    sudo mkdir -p "$new_mount_point"
    if [ ! -d "$new_mount_point" ]; then
        echo "Error: No se pudo crear el directorio de montaje '$new_mount_point'."
        return 1
    fi

    # Verificar que exista la carpeta del nuevo grupo en /srv/ftp
    if [ ! -d "/srv/ftp/$nuevo_grupo_name" ]; then
        echo "Error: La carpeta /srv/ftp/$nuevo_grupo_name no existe."
        return 1
    fi

    # Realizar montaje bind para la carpeta del nuevo grupo
    sudo mount --bind "/srv/ftp/$nuevo_grupo_name" "$new_mount_point"
    if [ $? -eq 0 ]; then
        echo "Montaje bind realizado: /srv/ftp/$nuevo_grupo_name -> $new_mount_point"
    else
        echo "Error: no se pudo montar la carpeta del grupo '$nuevo_grupo_name' en '$new_mount_point'."
    fi

    echo "Usuario '$username' cambiado del grupo '$grupo_actual' al grupo '$nuevo_grupo_name' exitosamente."
}