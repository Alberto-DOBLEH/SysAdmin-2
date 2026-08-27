# SysAdmin-2 Project Context

This file keeps project-specific context for future agent sessions. Update it whenever a practice, module, verification, or VM result changes.

## Purpose

SysAdmin-2 contains automation scripts for university system administration practices on Ubuntu Server and Windows Server virtual machines.

The main goal is to keep each practice reproducible after a clean VM clone where the only guaranteed installed tool is `git`.

## Operating Workflow

1. User requests a specific practice.
2. Agent reviews the current repo structure and existing modules relevant to that practice.
3. Agent implements or adjusts the required modules and main scripts for Ubuntu Server, Windows Server, or both, depending on the user's instruction.
4. Agent verifies syntax/basic behavior when possible in the local workspace.
5. Agent pushes the completed script when explicitly requested or when the practice workflow requires it.
6. User opens the target VM, connects from the Linux client VM through SSH, runs `git pull`, and executes the main script.
7. If the user confirms the practice worked in VM, update this file with the working status.

## VM Baseline

- Server VMs start clean for each practice.
- The only guaranteed preinstalled package/tool is `git`.
- Any dependency needed by a practice must be installed by the script itself.
- If a future practice has a different baseline, the user will explicitly say so.

## Network Model

Each server VM has two network adapters:

- One adapter for internet access and dependency downloads.
- One internal adapter for communication between VMs without affecting the host.

Adapter names may be treated as fixed after the user provides them because the VMs are cloned and the names remain stable.

For the first practice that needs adapter-specific work, the user will provide the adapter names for Ubuntu Server and Windows Server. After that, keep them as project context in this file.

### Network Rules

- Do not touch the internet adapter unless a practice explicitly requires it.
- Configure only the internal adapter when a static internal IP is required.
- It is acceptable to use fixed adapter names once the user provides them.
- If an internal adapter is dynamic and the practice needs a static IP, configure it as static.
- Avoid setting a default gateway on the internal adapter unless the practice explicitly requires it.
- Preserve internet connectivity for downloading dependencies.

### Known Adapter Names

Pending user confirmation.

Use this section after the user provides the names:

| System | Internet Adapter | Internal Adapter | Notes |
| --- | --- | --- | --- |
| Ubuntu Server | Pending | Pending | Pending |
| Windows Server | Pending | Pending | Pending |

## Path Rules

Never use absolute repository paths in practice scripts or modules.

Scripts are executed after `git pull` inside the VM, so module loading must work regardless of the current shell location.

### Linux Module Loading Pattern

Use this pattern in Linux scripts:

```bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/Modulos_Linux/generales.sh"
source "$REPO_ROOT/Modulos_Linux/modulos_redes.sh"
```

For modules that source other modules, use `${BASH_SOURCE[0]}` to resolve paths relative to the module file itself.

Current good example: `Modulos_Linux/usuarios.sh` resolves `validadores.sh` dynamically from its own directory.

### Windows Module Loading Pattern

Use this pattern in PowerShell scripts:

```powershell
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ModulosPath = Join-Path $RepoRoot "Modulos_Windows"

. (Join-Path $ModulosPath "generales.ps1")
. (Join-Path $ModulosPath "modulos_redes.ps1")
```

Current good examples: several Windows scripts already use `$PSScriptRoot` and `Join-Path`.

## Console Output Rules

- Scripts should show important progress and errors only.
- Dependency installation and long commands should be quiet where practical.
- Avoid flooding the console with full package-manager logs unless troubleshooting is needed.
- Prefer clear checkpoints: installing dependencies, configuring service, opening firewall, restarting service, final status.

## Script Structure Rules

- Main practice scripts should orchestrate the flow.
- Reusable logic belongs in `Modulos_Linux` or `Modulos_Windows`.
- Define functions and load modules before calling functions.
- Avoid duplicated logic across practice scripts when a module already exists or should exist.
- Prefer small, direct modules over large mixed-purpose files when adding new functionality.

## Current Repository Structure

```text
README.md
PROJECT_CONTEXT.md
Modulos_Linux/
  contenedores.sh
  generales.sh
  librerianueva.sh
  modulos_redes.sh
  usuarios.sh
  validadores.sh
Modulos_Windows/
  generales.ps1
  librerianueva.ps1
  modulos_redes.ps1
  usuarios.ps1
  validadores.ps1
Practica_1/
  tarea1_diagnostico.sh
  tarea1_diagnostico.ps1
Practica_2/
  DHCP.sh
  DHCP.ps1
Practica_3/
  DNS.sh
  DNS.ps1
Practica_4/
  SSH.sh
  SSH.ps1
Practica_5/
  FTP.sh
  FTP.ps1
Practica_6/
  HTTP.sh
  HTTP.ps1
Practica_7/
  main.sh
  ftp.sh
  ftp.ps1
  http.sh
  http.ps1
  funciones_http.sh
  usuarios_ftp.sh
Practica_10/
  main.sh
  revision.sh
  VALIDACION.md
  web/
    Dockerfile
    nginx.conf
    site/
  ftp/
    Dockerfile
    vsftpd.conf
    entrypoint.sh
Practica_11/
  main.sh
  revision.sh
  docker-compose.yml
  .env.example
  VALIDACION.md
  REPORTE.md
  nginx/
  app/
  postgres/
Practica_12/
  main.sh
  revision.sh
  docker-compose.yml
  .env.example
  .gitignore
  VALIDACION.md
  REPORTE.md
  config/
    postfix-accounts.cf
    postfix-main.cf
    dovecot-quotas.cf
    opendkim/
```

## Module Inventory

### Linux Modules

| Module | Current Purpose | Notes / Risks |
| --- | --- | --- |
| `Modulos_Linux/contenedores.sh` | Helper module for Docker installation, Docker Compose availability, Docker network/volume creation, image builds, container recreation, PostgreSQL readiness checks, web volume seeding, and automated PostgreSQL backup timer setup. | Used by practices 10 and 11. Uses Docker CLI and systemd. VM execution pending user confirmation. |
| `Modulos_Linux/generales.sh` | Provides `verificar_servicio` to install apt packages if missing. | Uses `apt update -y` and `apt install -y`. Output is not very quiet. |
| `Modulos_Linux/modulos_redes.sh` | Provides `asignar_ip_estatica`. | Currently assumes `enp0s3` for internet and `enp0s8` for internal adapter, rewrites `/etc/netplan/50-cloud-init.yaml`, and sets a default route through the internal IP. Needs review before reuse. Fixed names are acceptable only after user confirms them. |
| `Modulos_Linux/validadores.sh` | IPv4, subnet mask, network/broadcast, text, password, username validations. | Uses some shell utilities like `awk`. Generally reusable. |
| `Modulos_Linux/usuarios.sh` | FTP user management: create, delete, change group; sources `validadores.sh` dynamically. | Good module-loading pattern. Some variable issues exist, e.g. password validation references `$usuario` while username variable is `$username`; delete flow uses `$group_name` without determining it. Needs review before relying on it. |
| `Modulos_Linux/librerianueva.sh` | Large mixed FTP and HTTP function library. | Contains duplicated `instalar_dependencias` definitions and mixes multiple practices/services. Useful but should be split or carefully reused. |

### Windows Modules

| Module | Current Purpose | Notes / Risks |
| --- | --- | --- |
| `Modulos_Windows/generales.ps1` | Provides `verificar-servicio` using `Get-WindowsFeature`. | Small and reusable for Windows Server roles/features. |
| `Modulos_Windows/modulos_redes.ps1` | IPv4 format validation, static IP assignment, segment helpers. | Currently assumes internal adapter name `Ethernet 2`. Fixed names are acceptable only after user confirms them. Function `asignar-ip-estatica` references `$regex` without defining it locally. |
| `Modulos_Windows/validadores.ps1` | IPv4, network details, text, password, username, group, and port validations. | Mostly reusable. `validar_grupo_existente` uses `Get-ADGroup`, which requires AD module/domain context and may not fit local groups. |
| `Modulos_Windows/usuarios.ps1` | FTP user manager for local users and folder junctions. | Has a suspicious top line that builds a path but does not dot-source/import `validadores.ps1`. Depends on functions from `validadores.ps1` being loaded by caller. |
| `Modulos_Windows/librerianueva.ps1` | Large mixed FTP and HTTP function library for IIS/Apache/Tomcat. | Contains many useful service install/config functions, but it is broad and should be reused carefully. |

## Practice Log

This log records what exists now, not necessarily what has been verified as working in clean VMs.

| Practice | Ubuntu Script | Windows Script | Current Status | Notes |
| --- | --- | --- | --- | --- |
| Practice 1 | `Practica_1/tarea1_diagnostico.sh` | `Practica_1/tarea1_diagnostico.ps1` | Existing, not reviewed deeply in this context pass. | Diagnostic practice. |
| Practice 2 | `Practica_2/DHCP.sh` | `Practica_2/DHCP.ps1` | Existing, needs modernization before reuse. | Linux uses fixed `enp0s8` and fixed `77.77.77.0/24`. Windows duplicates network helper functions and uses `Ethernet 2`. |
| Practice 3 | `Practica_3/DNS.sh` | `Practica_3/DNS.ps1` | Existing, needs path/network improvements before reuse. | Linux uses fragile `source ../Modulos_Linux/...`. Windows uses dynamic module path. Both configure DNS zones. |
| Practice 4 | `Practica_4/SSH.sh` | `Practica_4/SSH.ps1` | Existing, needs path/network improvements before reuse. | Linux uses fragile module paths. Windows uses dynamic module paths. Both configure SSH. |
| Practice 5 | `Practica_5/FTP.sh` | `Practica_5/FTP.ps1` | Existing, needs review before reuse. | FTP setup and user management exist. Some logic duplicated outside modules. |
| Practice 6 | `Practica_6/HTTP.sh` | `Practica_6/HTTP.ps1` | Existing, needs path improvements on Linux. | Linux uses fragile `source ../Modulos_Linux/librerianueva.sh`; Windows uses `$PSScriptRoot`. |
| Practice 7 | `Practica_7/main.sh` plus service scripts | `Practica_7/ftp.ps1`, `Practica_7/http.ps1` | Existing, needs review/fixes before reuse. | `main.sh` calls `instalar_dependencias` before declaring it, which will fail in Bash. Some internal script loading uses `dirname "$0"`, which is better. |
| Practice 10 | `Practica_10/main.sh` | Not applicable | Implemented locally, VM validated and working. | Linux-only. Deploys Docker containers for custom Alpine Nginx web, PostgreSQL, and FTP on bridge network `infra_red` (`172.20.0.0/16`) with volumes `db_data` and `web_content`, resource limits, and automated PostgreSQL backups to `/opt/sysadmin10/backups`. Fix applied: web Dockerfile removed `USER webuser` to resolve nginx startup crash. All 4 revision tests pass. |
| Practice 11 | `Practica_11/main.sh` | Not applicable | Implemented locally, VM validation pending. | Linux-only IaC practice using `docker-compose.yml`, `.env`, Nginx load balancer, internal app, PostgreSQL, pgAdmin isolated from host ports, SSH tunnel support, firewall rules, healthchecks, restart policies, and named volume `db_data`. |
| Practice 12 | `Practica_12/main.sh` | Not applicable | Implemented locally, VM validation pending. | Linux-only mail server practice using docker-mailserver plus Roundcube webmail, preconfigured mail accounts and DKIM keys, internal DB network, and automated review. |

## Practice 10 Implementation Notes

- Target system: Ubuntu Server only.
- Main script: `Practica_10/main.sh`.
- New module: `Modulos_Linux/contenedores.sh`.
- Web image: custom `sysadmin10-web:1.0`, based on `alpine:3.20`, installs Nginx, disables `server_tokens`, listens on port `8080`, and runs as root inside the container (Docker namespace isolation provides the security boundary). Earlier versions ran as non-root `webuser` UID `1000` but this caused nginx to crash on startup due to Alpine temp directory permission issues.
- Web content: custom static HTML/CSS/SVG under `Practica_10/web/site`; seeded into Docker volume `web_content`.
- Database: `postgres:16-alpine`, container `sysadmin10_postgres`, persistent volume `db_data`, database `usuarios`, user `admin`, initial table `usuarios_app` with demo row `admin_demo`.
- FTP image: custom `sysadmin10-ftp:1.0`, based on `alpine:3.20`, uses vsftpd and shares the same `web_content` volume for uploads.
- Docker network: bridge network `infra_red` with subnet `172.20.0.0/16`.
- Resource limits: containers are launched with `--memory 512m` and `--cpus 0.50`.
- Published service IP: `main.sh` detects IPv4 addresses and prompts the user to select the internal server IP when multiple addresses exist.
- PostgreSQL backups: systemd timer `sysadmin10-pg-backup.timer` runs `/usr/local/bin/sysadmin10_pg_backup.sh` every 10 minutes and stores dumps in `/opt/sysadmin10/backups`.
- Validation guide: `Practica_10/VALIDACION.md` includes persistence, network isolation, FTP/web shared-volume, and resource-limit checks.
- Automated review: `Practica_10/revision.sh` runs the four validation tests on the server itself, recreates the DB container to prove persistence, uploads a file via FTP, checks web visibility, shows `docker stats --no-stream`, and writes an evidence log `revision_<fecha>_<hora>.log`.
- VM status: confirmed working by user. All 4 automated revision tests pass (10.1 persistencia BD, 10.2 aislamiento de red, 10.3 permisos FTP y publicacion web, 10.4 limites de recursos).

## Practice 11 Implementation Notes

- Target system: Ubuntu Server only.
- Main script: `Practica_11/main.sh`.
- Orchestration file: `Practica_11/docker-compose.yml`.
- Environment example: `Practica_11/.env.example`; `main.sh` creates `.env` from it if missing and all credentials/ports are referenced through environment variables.
- Report base: `Practica_11/REPORTE.md` includes a copy of the compose, `.env` example, Mermaid diagram, and test-log table.
- Validation guide: `Practica_11/VALIDACION.md` covers isolation, internal DNS, SSH tunnel, persistence, and healthcheck behavior.
- Services: `balanceador_nginx`, `app_interna`, `base_datos`, and `servidor_pgadmin`.
- Public entrypoint: only Nginx publishes `${FRONTEND_PORT}:8080`; app, PostgreSQL, and pgAdmin do not publish host ports.
- Networks: `red_publica` bridge for Nginx/app and `red_datos` internal bridge for PostgreSQL/pgAdmin; Nginx also joins `red_datos` for required internal DNS validation.
- Security: Nginx disables `server_tokens`; app and Nginx custom images run as non-root users. Firewall allows SSH/frontend and denies common PostgreSQL/pgAdmin host ports.
- SSH tunnel: `main.sh` updates `/etc/hosts` with `servidor_pgadmin` and `servidor_postgres` container IPs so `ssh -L 8080:servidor_pgadmin:80 usuario@IP_SERVIDOR` works from the client.
- Persistence: PostgreSQL uses named volume `db_data` and init script `postgres/init.sql` creates table `usuarios_app` with demo row.
- Resilience: services use `restart: always`; pgAdmin depends on PostgreSQL `service_healthy`.
- Automated review: `Practica_11/revision.sh` runs the four acceptance tests on the server, checks hidden ports and published-port absence, pings the DB service name from Nginx, attempts an SSH tunnel to pgAdmin, stops/restarts the stack with `docker compose down/up` to prove persistence and healthcheck ordering, refreshes `/etc/hosts`, and writes an evidence log `revision_<fecha>_<hora>.log`.
- VM status: not yet confirmed by user.

## Practice 12 Implementation Notes

- Target system: Ubuntu Server only.
- Main script: `Practica_12/main.sh`.
- Orchestration file: `Practica_12/docker-compose.yml`.
- Environment example: `Practica_12/.env.example`; `main.sh` creates `.env` from it if missing and all credentials are referenced through environment variables.
- Services: `mailserver` (docker-mailserver), `roundcube-db` (MariaDB 10.5), and `roundcubemail` (Roundcube webmail).
- Container names kept identical to the reference repo (ADMINISTRACION-DE-SISTEMAS): `mailserver`, `roundcube-db`, `roundcubemail`, so documented `docker exec mailserver setup ...` commands work as-is.
- Published ports: `25` SMTP, `143` IMAP, `587` submission, `993` IMAPS on mailserver; `8081:80` for Roundcube webmail. MariaDB is not published.
- Networks: `red_correo` bridge for mailserver/webmail and `red_datos_interna` internal bridge for MariaDB; webmail joins both.
- Persistence: named volumes `mail_data`, `mail_state`, and `roundcube_db_data`; mail logs bound to `Practica_12/logs` (gitignored).
- Preconfigured accounts: `Practica_12/config/postfix-accounts.cf` ships five accounts for `reprobados.com` (director, admin, kami, goku, vegeta) with password `PasswordSegura123!` (hash verified locally with python crypt). DKIM keys for `mail._domainkey.reprobados.com` are committed under `config/opendkim/`.
- Firewall: `main.sh` enables ufw and allows SSH 22 plus TCP 25/143/587/993/8081.
- Automated review: `Practica_12/revision.sh` checks the stack is up and MariaDB healthy, verifies ports respond, lists the five accounts, sends a test mail via `sendmail` and confirms `status=sent` in the mail log, checks webmail responds on 8081, shows DKIM info, and writes an evidence log `revision_<fecha>_<hora>.log`.
- Validation/report bases: `Practica_12/VALIDACION.md` and `Practica_12/REPORTE.md`.
- VM status: not yet confirmed by user.

## Known Technical Debt

- Linux scripts often need dynamic module paths instead of `../Modulos_Linux/...`.
- Network modules need adapter-name handling based on user-provided fixed VM names.
- Linux network configuration should avoid overwriting unrelated Netplan configuration when possible.
- Some scripts use hardcoded IP ranges or adapter names from older assumptions.
- Large `librerianueva.*` files mix FTP and HTTP responsibilities.
- Practice scripts should reduce duplicated code and rely more on modules.
- Several scripts need quieter dependency installation and clearer final status messages.

## Future Update Checklist

Update this file whenever work is done.

For each changed practice, record:

- Practice number/name.
- Target system: Ubuntu Server, Windows Server, or both.
- Main scripts changed.
- Modules created or modified.
- What each modified module does.
- Dependencies installed by the script.
- Network adapter names used.
- IP/segment assumptions.
- Verification done locally.
- VM result after user testing.
- Known remaining issues.

For each new or changed module, update the module inventory with:

- Function names added/changed.
- Purpose.
- Required inputs.
- Side effects on the system.
- Whether it is considered working in VM.

## Confirmed VM Results

No VM execution results have been confirmed in this context file yet.

Add entries here after user confirms a script worked inside the target VM.

| Date | Practice | System | Result | Notes |
| --- | --- | --- | --- | --- |
| 2026-08-27 | Practice 10 | Ubuntu Server | PASS | All 4 revision tests passed. Fix: removed `USER webuser` from web Dockerfile to resolve nginx crash on Alpine 3.20. |
