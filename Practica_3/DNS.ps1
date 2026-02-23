#Importacion de modulos para la practica
$modulosPath = Join-Path $PSScriptRoot "..\Modulos_Windows"

. (Join-Path $modulosPath "modulos_redes.ps1")
. (Join-Path $modulosPath "generales.ps1")

asignar-ip-estatica

$servicio = "DNS"
$validacion = verificar-servicio -Servicio $servicio

if($validacion -eq $true) {
    Write-Host "El servicio de DNS ya esta instalado" -ForegroundColor Green
} else  {
    Write-Host "Servicio DNS no esta instalado"
    Write-Host "Empezando proceso de instalacion.."

    Install-WindowsFeature -Name "DNS" -IncludeManagementTools
}

do{
    #Variables de iteracion
    [string]$dominio
    [string]$ip
    $iteracion = $true
 
    do{
        $dominio = Read-Host "Ingrese el dominio deseado en terminacion.com:"
            
        if([string]::IsNullOrEmpty($dominio)){
            Write-Host "Dominio no puede ser vacio" -ForegroundColor Red
        }elseif($dominio -match "\.com$"){
            Write-Host "Dominio Valido" -ForegroundColor Green
            Break
        }else{
            Write-Host "El dominio no puede ser vacio" -ForegroundColor Green
        }
    }while($true)

    do{
        $ip = Read-Host "Ingrese la direccion IP que se va apuntar:"
        $validacion = verificar-formato-ip -IP $ip
        if($validacion) {
            Break
        }
    }while($true)

    #Creacion de la primary zone
    Add-DnsServerPrimaryZone -Name $dominio -ZoneFile "$dominio.dns" -DynamicUpdate NonsecureAndSecure
    Write-Host "Se registro la Primary Zone del dominio: $dominio" -ForegroundColor Green

    #Creacion de registros
    Add-DnsServerResourceRecordA -Name "@" -ZoneName $dominio -IPv4Address $ip
    Add-DnsServerResourceRecordA -Name "www" -ZoneName $dominio -IPv4Address $ip
    Write-Host "Se generaron los registros" -ForegroundColor Green

    Write-Host "Dominio configurado con exito"

    do{
        $res = Read-Host "Quiere registrar otro dominio(S/N) "

        switch($res) {
            "S" {
                break
            }
            "N" {
                $iteracion = $false
                break
            }
            default {
                Write-Host "Favor de ingresar una opcion valida" -ForegroundColor Red
            }
        }
    }while($true)
    
}while($iteracion -eq $true)

Write-Host "Reiniciando el servicio de DNS"
Restart-Service -Name DNS
Write-Host "Servicio reestablecido"
