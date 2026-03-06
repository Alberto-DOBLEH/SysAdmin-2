validar_ipv4() {
  local ip="$1"

  # Verificar si la cadena está vacía
  if [[ -z "$ip" ]]; then
    echo "La cadena está vacía"
    return 1
  fi

  # Verificar el formato general de IPv4 (cuatro números separados por puntos)
  if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "El formato de la IP no es correcto"
    return 1
  fi

  # Separar los números en un array
  IFS='.' read -r -a octetos <<< "$ip"

  # Verificar que haya cuatro números
  if [[ ${#octetos[@]} -ne 4 ]]; then
    echo "La IP no tiene cuatro octetos"
    return 1
  fi

  # Verificar que cada número esté entre 0 y 255
  for octeto in "${octetos[@]}"; do
    if [[ ! "$octeto" =~ ^[0-9]+$ ]] || [[ "$octeto" -lt 0 ]] || [[ "$octeto" -gt 255 ]]; then
        echo "El octeto $octeto no es válido"
      return 1
    fi
  done

  return 0
}

calcular_mascara_subred() {
    local cidr=$1

    # Inicializar la máscara de subred
    local mascara=""

    # Calcular la máscara de subred basada en el CIDR
    for i in {1..32}; do
        if [ $i -le $cidr ]; then
            mascara+="1"
        else
            mascara+="0"
        fi

        # Agregar un punto cada 8 bits
        if [ $((i % 8)) -eq 0 ] && [ $i -ne 32 ]; then
            mascara+="."
        fi
    done

    # Convertir la máscara binaria a formato decimal
    local octetos=(${mascara//./ })
    local mascara_decimal=""

    for octeto in "${octetos[@]}"; do
        mascara_decimal+=$((2#$octeto))
        mascara_decimal+="."
    done

    #Retornar la máscara de subred
    echo "${mascara_decimal%?}"
}

calcular_red_broadcast() {
    local ip="$1"

    # Extraer los primeros tres octetos de la IP
    local base=$(echo "$ip" | awk -F. '{print $1"."$2"."$3}')

    #Retornar los valores de la red y broadcast
    printf "${base}.0|${base}.255"
}

# Validación por textos vacíos
validar_textos_nulos() {
    local texto="$1"
    [[ -n "$texto" ]]
}

# Validación de que el username no tenga espacios
validar_espacios() {
    local usuario="$1"
    [[ "$usuario" =~ \  ]] && return 1 || return 0
}

# Validación de formato de contraseña
validar_contrasena() {
    local contrasena="$1"
    local usuario="$2"

    # Verificar la longitud de la contraseña (mínimo 8, máximo 12)
    if [[ ${#contrasena} -lt 8 || ${#contrasena} -gt 12 ]]; then
        return 1
    fi

    # Verificar si contiene al menos una letra mayúscula
    if ! [[ "$contrasena" =~ [A-Z] ]]; then
        return 1
    fi

    # Verificar si contiene al menos un número
    if ! [[ "$contrasena" =~ [0-9] ]]; then
        return 1
    fi

    # Verificar si la contraseña contiene el nombre de usuario (ignorando mayúsculas/minúsculas)
    if [[ -n "$usuario" && "${contrasena,,}" == *"${usuario,,}"* ]]; then
        return 1
    fi

    return 0
}

# Validación de caracteres especiales
validar_sin_caracteres_especiales() {
    local texto="$1"
    [[ "$texto" =~ [^a-zA-Z0-9] ]] && return 1 || return 0
}

# Validación de 20 caracteres
validar_longitud_maxima() {
    local texto="$1"
    [[ ${#texto} -gt 20 ]] && return 1 || return 0
}

# Validación de que el usuario ya existe
validar_usuario_existente() {
    local usuario="$1"
    id "$usuario" &>/dev/null
}