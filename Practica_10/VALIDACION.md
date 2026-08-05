# Practica 10 - Guia De Validacion

Ejecutar el despliegue en Ubuntu Server desde la carpeta de la practica:

```bash
cd Practica_10
sudo bash main.sh
```

Si la VM tiene varias IPv4, el script pedira seleccionar la IP interna que se usara para publicar Web y FTP hacia la VM cliente.

## Servicios Desplegados

| Servicio | Contenedor | Puerto Host | Red | Volumen |
| --- | --- | --- | --- | --- |
| Web Nginx personalizado | `sysadmin10_web` | `8080` | `infra_red` | `web_content` solo lectura |
| PostgreSQL | `sysadmin10_postgres` | `5432` | `infra_red` | `db_data` |
| FTP | `sysadmin10_ftp` | `21`, `21100-21110` | `infra_red` | `web_content` lectura/escritura |

Credenciales de practica:

| Servicio | Usuario | Password |
| --- | --- | --- |
| PostgreSQL | `admin` | `SysAdmin10!` |
| FTP | `ftpadmin` | `SysAdmin10!` |

## Prueba 10.1 - Persistencia De BD

Crear datos de prueba:

```bash
sudo docker exec sysadmin10_postgres psql -U admin -d usuarios -c "CREATE TABLE IF NOT EXISTS alumnos(id serial primary key, nombre text);"
sudo docker exec sysadmin10_postgres psql -U admin -d usuarios -c "INSERT INTO alumnos(nombre) VALUES ('prueba_persistencia');"
sudo docker exec sysadmin10_postgres psql -U admin -d usuarios -c "SELECT * FROM alumnos;"
```

Eliminar el contenedor y levantar uno nuevo usando el mismo volumen:

```bash
sudo docker rm -f sysadmin10_postgres
sudo docker run -d --name sysadmin10_postgres --network infra_red --memory 512m --cpus 0.50 --restart unless-stopped -e POSTGRES_USER=admin -e POSTGRES_PASSWORD='SysAdmin10!' -e POSTGRES_DB=usuarios -v db_data:/var/lib/postgresql/data -p 5432:5432 postgres:16-alpine
sudo docker exec sysadmin10_postgres psql -U admin -d usuarios -c "SELECT * FROM alumnos;"
```

La fila `prueba_persistencia` debe seguir existiendo.

## Prueba 10.2 - Aislamiento De Red

Verificar resolucion por nombre dentro de `infra_red`:

```bash
sudo docker exec sysadmin10_web ping -c 3 sysadmin10_postgres
```

Debe responder usando el nombre del contenedor de base de datos.

## Prueba 10.3 - Permisos FTP Y Publicacion Web

Desde el cliente Linux o desde el servidor si tiene cliente FTP instalado, subir un archivo al directorio `uploads`.

Ejemplo con `curl` desde una maquina cliente:

```bash
printf 'archivo subido por ftp\n' > prueba_ftp.txt
curl -T prueba_ftp.txt ftp://IP_DEL_SERVIDOR/uploads/prueba_ftp.txt --user ftpadmin:'SysAdmin10!'
```

Validar desde navegador o consola:

```bash
curl http://IP_DEL_SERVIDOR:8080/uploads/prueba_ftp.txt
```

El contenido del archivo debe mostrarse desde el servidor web.

## Prueba 10.4 - Limites De Recursos

Ejecutar:

```bash
sudo docker stats --no-stream
```

La evidencia debe mostrar limite de memoria configurado, por ejemplo `512MiB`, en los contenedores.

## Respaldos PostgreSQL

El script configura un timer de systemd que ejecuta respaldos cada 10 minutos:

```bash
systemctl status sysadmin10-pg-backup.timer
ls -lh /opt/sysadmin10/backups
```

Tambien se genera un respaldo inicial al finalizar el despliegue.
