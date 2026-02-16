#Funciones principales
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



#Variables de uso
$ipserver = ""
$segmento = ""
$iniciorango = ""
$finalrango = ""
$gateway = ""
$dns = ""

#Variables de filtro
$FeatureName = "DHCP" #Nombre del servicio para el filtro
$regex = "^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])$" #Regex para verificar el formato de las IPv4
$service = Get-WindowsFeature -Name $FeatureName -ErrorAction SilentlyContinue #Comando para verificar si esta el servicio

if ($null -ne $service) {
    Write-Host "El servicio DHCP ya está instalado."

    Write-Host "Verificando si esta corriendo..."
    Get-Service -Name DHCP
} else {
    Write-Host "El servicio de DHCP no esta instalado"
    Write-Host "Iniciando con el proceso de instalacion y configuracion.."

    $adapter = Get-NetIPInterface -InterfaceAlias "Ethernet 2" -AddressFamily IPv4 # Variable para ver si es Dinamica o no el adaptador

    if ($adapter.Dhcp -eq "Enabled") {
        Write-Host "La IP es dinámica."

        do{
            $ipserver = Read-Host "Ingrese la IP que quiere para el servidor: " 

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

        $segmento = Obtener-Segmento -IPv4 $ipserver

        do{
            $iniciorango = Read-Host "Ingrese el inicio del rango: " 

            if ($iniciorango -match $regex){
                Write-Host "La IP es valida" -ForegroundColor Green

                $validacion = verificar-segmento -ip $iniciorango -seg $segmento

                if($validacion -eq $true){
                    $valida = $true
                } else {
                    Write-Host "La IP no es parte del segmento del servidor" -ForegroundColor Red
                    $valida = $false
                }
            }else {
                Write-Host "La IP es no es valida, favor de ingresar otra" -ForegroundColor Red
                $valida = $false
            }
        }while(-not $valida)

        do{
            $finalrango = Read-Host "Ingrese el inicio del rango: " 

            if ($finalrango -match $regex){
                Write-Host "La IP es valida" -ForegroundColor Green

                $validacion = verificar-segmento -ip $finalrango -seg $segmento

                if($validacion -eq $true){
                    $valida = $true
                } else {
                    Write-Host "La IP no es parte del segmento del servidor" -ForegroundColor Red
                    $valida = $false
                }
            }else {
                Write-Host "La IP es no es valida, favor de ingresar otra" -ForegroundColor Red
                $valida = $false
            }
        }while(-not $valida)

        do{
            $gateway = Read-Host "Ingrese el gateway del servicio: " 

            if ($gateway -match $regex){
                Write-Host "La IP es valida" -ForegroundColor Green

                $validacion = verificar-segmento -ip $gateway -seg $segmento

                if($validacion -eq $true){
                    $valida = $true
                } else {
                    Write-Host "La IP no es parte del segmento del servidor" -ForegroundColor Red
                    $valida = $false
                }
            }else {
                Write-Host "La IP es no es valida, favor de ingresar otra" -ForegroundColor Red
                $valida = $false
            }
        }while(-not $valida)

        do{
            $dns = Read-Host "Ingrese el DNS del servicio: " 

            if ($dns -match $regex){
                Write-Host "La IP es valida" -ForegroundColor Green
                $valida = $true
            }else {
                Write-Host "La IP es no es valida, favor de ingresar otra" -ForegroundColor Red
                $valida = $false
            }
        }while(-not $valida)

        Write-Host "Instalando el servicio de DHCP...."
        Install-WindowsFeature -Name DHCP -IncludeManagementTools

        Write-Host "Asignando las configuraciones del DHCP..."
        Add-DhcpServerv4Scope -Name $nombre -StartRange $iniciorango -EndRange $finalrango -State Active
        Set-DhcpServerv4OptionValue -ScopeId $segmento -OptionId 3 -Value $ipserver

        Write-Host "Reiniciando el servicio de DHCP..."
        Restart-Service -Name DHCP -Force

    } else {
        Write-Host "La IP  ya es estática."
    }

    Write-Host "Verificando si esta corriendo..."
    Get-Service -Name DHCP
}