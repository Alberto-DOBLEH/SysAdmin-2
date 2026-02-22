#Importacion de modulos para la practica
$modulosPath = Join-Path $PSScriptRoot "..\Modulos_Windows"

. (Join-Path $modulosPath "modulos_redes.ps1")
. (Join-Path $modulosPath "generales.ps1")

asignar-ip-estatica

#Instalar OpenSSH
Write-Host "Instalando OpenSSH" -ForegroundColor Green
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Get-Module -ListAvailable -Name NetSecurity

#Verificar si OpenSSH está instalado
Write-Host "Verificando si OpenSSH está instalado" -ForegroundColor Green
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'

#Iniciar el servicio
Write-Host "Iniciando el servicio de OpenSSH" -ForegroundColor Green
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

#Modificar el firewall
Write-Host "Modificando el firewall para permitir el acceso SSH" -ForegroundColor Green
New-NetFirewallRule -Name "SSH" -DisplayName 'OpenSSH Server' -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow 

#Verificar el servicio
Write-Host "Verificando el servicio de OpenSSH" -ForegroundColor Green
Get-Service sshd