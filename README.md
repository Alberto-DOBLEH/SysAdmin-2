# SysAdmin-2

Repositorio de practicas de administracion de sistemas para automatizar configuraciones en Ubuntu Server y Windows Server.

El objetivo es que cada practica pueda ejecutarse en maquinas virtuales limpias despues de hacer `git pull`, instalando desde el script las dependencias necesarias y usando modulos reutilizables para evitar repetir logica.

## Estructura

- `Practica_*`: scripts principales de cada practica.
- `Modulos_Linux`: funciones reutilizables para scripts Bash en Ubuntu Server.
- `Modulos_Windows`: funciones reutilizables para scripts PowerShell en Windows Server.
- `PROJECT_CONTEXT.md`: contexto operativo del proyecto para futuras sesiones y agentes.

## Flujo De Uso

1. Entrar a la VM correspondiente.
2. Actualizar el repositorio con `git pull`.
3. Ejecutar el script principal de la practica solicitada.
4. Probar el servicio/configuracion desde la VM cliente cuando aplique.

## Notas Del Proyecto

- Las VMs limpias solo tienen `git` instalado por defecto.
- Los scripts deben instalar sus propias dependencias.
- Los modulos deben cargarse con rutas dinamicas, no con rutas absolutas.
- Los adaptadores de red pueden manejarse con nombres fijos cuando se documenten en `PROJECT_CONTEXT.md`, ya que las VMs son clones.
- La salida en consola debe enfocarse en mensajes importantes y estados finales.

## Para Agentes

Antes de modificar practicas o modulos, revisar `PROJECT_CONTEXT.md` para mantener el contexto del proyecto actualizado.

Cada cambio importante debe registrar ahi que practica se trabajo, que modulos se tocaron, que hace cada modulo y si la prueba en VM quedo confirmada.
