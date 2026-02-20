function verificar-servicio {
    param (
        [string]$Servicio
    )
    $Feature = Get-WindowsFeature -Name $Servicio -ErrorAction SilentlyContinue #Comando para verificar si esta el servicio

    if ($Feature.Installed) {
        return $true
    } else {
        return $false
    }
}
