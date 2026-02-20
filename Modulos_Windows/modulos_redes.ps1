function verificar-formato-ip{
    param (
        [string]$IP
    )

    $regex = "^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])$"

    if ($IP -match $regex){
        return $true
    } else {
        return $false
    }
}

function asignar-ip-estatica {
    $adapter = Get-NetIPInterface -InterfaceAlias "Ethernet 2" -AddressFamily IPv4 # Variable para ver si es Dinamica o no el adaptador

    if ($adapter.Dhcp -eq "Enabled") {
        Write-Host "La IP es dinámica." -ForegroundColor Yellow

        #Seccion de ingreso de datos
        #La IP del servidor
        do{
            $ipserver = Read-Host "Ingrese la IP que quiere para el servidor " 

            if ($ipserver -match $regex){
                Write-Host "La IP es valida" -ForegroundColor Green
                $valida = $true
            }else {
                Write-Host "La IP es no es valida, favor de ingresar otra" -ForegroundColor Red
                $valida = $false
            }
        }while(-not $valida)

        Write-Host "Asignando la IP estatica al Servidor ...."
        New-NetIPAddress -InterfaceAlias 'Ethernet 2' -IPAddress $ipserver -PrefixLength 24
        
    } else {
        Write-Host "La IP  ya es estática."
    }
}


function Obtener-Segmento {
    param (
        [string]$IPv4
    )

    $octets = $IPv4.Split('.')

    return "$($octets[0]).$($octets[1]).$($octets[2]).0"
}

function verificar-segmento {
    param (
        [string]$ip,
        [string]$seg
    )

    $octip = $ip.Split(".")
    $octseg = $seg.Split(".")

    if (
        $octip[0] -eq $octseg[0] -and
        $octip[1] -eq $octseg[1] -and
        $octip[2] -eq $octseg[2]
    ) {
        return $true
    }
    else {
        return $false
    }
}
