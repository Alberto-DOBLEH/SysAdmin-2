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
```

## Module Inventory

### Linux Modules

| Module | Current Purpose | Notes / Risks |
| --- | --- | --- |
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
| Pending | Pending | Pending | Pending | Pending |
