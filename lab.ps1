# =============================================================================
#  soc-lab · gestor del laboratorio (Windows PowerShell)
#  Uso:  .\lab.ps1 setup   (ver .\lab.ps1 help)
#  Si PowerShell bloquea el script:
#     Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
# =============================================================================
param(
    [Parameter(Position = 0)][string]$Command = "help",
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$MinMemGB = 6
$CertsDir = "wazuh\certs"

function Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Info($m) { Write-Host "-->  $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[!]  $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[X]  $m" -ForegroundColor Red; exit 1 }

function Compose {
    & docker compose @args
    if ($LASTEXITCODE -ne 0) { Fail "docker compose $($args -join ' ') ha fallado" }
}

function Get-EnvValue($key, $default) {
    if (Test-Path .env) {
        $line = Get-Content .env | Where-Object { $_ -match "^$key=" } | Select-Object -Last 1
        if ($line) { $v = $line.Substring($key.Length + 1); if ($v) { return $v } }
    }
    return $default
}

function Show-Usage {
@"

  soc-lab · Laboratorio SOC del curso "De 0 a Analista SOC N2" (@DateUnH4ck)

  Uso: .\lab.ps1 <comando>

    setup             Primera instalación: comprueba requisitos, genera
                      certificados, construye imágenes y arranca todo
    up                Arranca el laboratorio
    down              Para el laboratorio (conserva alertas y agentes)
    status            Estado de contenedores y agentes Wazuh
    attacker          Abre una shell en la Kali atacante
    shell <servicio>  Abre una shell en un contenedor (srv-web, srv-ssh...)
    replay [args]     Reproduce ataques de Windows en Wazuh
                      (.\lab.ps1 replay --list  |  .\lab.ps1 replay dcsync)
    logs [servicio]   Muestra los logs (Ctrl+C para salir)
    reset             Borra TODOS los datos (alertas, agentes) y empieza de cero
    help              Esta ayuda

"@ | Write-Host
}

function Test-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Fail "Docker no está instalado. Instala Docker Desktop: https://www.docker.com/products/docker-desktop/"
    }
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) { Fail "Docker no está arrancado. Abre Docker Desktop y vuelve a probar." }
    & docker compose version *> $null
    if ($LASTEXITCODE -ne 0) { Fail "Falta Docker Compose v2. Actualiza Docker Desktop." }
    $ver  = & docker version --format '{{.Server.Version}}'
    $arch = & docker info --format '{{.Architecture}}'
    Ok "Docker $ver · arquitectura $arch"
}

function Test-Memory {
    $bytes = [int64](& docker info --format '{{.MemTotal}}')
    $gb = [math]::Floor($bytes / 1GB)
    if ($gb -lt $MinMemGB) {
        Warn "Docker solo tiene $gb GB de RAM. Recomendado: 8 GB (mínimo $MinMemGB)."
        Warn "Con WSL2, ajusta 'memory' en %UserProfile%\.wslconfig. Ver docs\requisitos.md"
    } else {
        Ok "Memoria disponible para Docker: $gb GB"
    }
}

function Set-MaxMapCount {
    # El indexer necesita vm.max_map_count >= 262144 en el kernel de Docker (WSL2).
    & docker run --rm --privileged alpine:3.20 sysctl -w vm.max_map_count=262144 *> $null
    if ($LASTEXITCODE -ne 0) { Fail "No he podido ajustar vm.max_map_count" }
    Ok "vm.max_map_count = 262144"
}

function Initialize-Env {
    if (-not (Test-Path .env)) { Copy-Item .env.example .env; Ok "Creado .env a partir de .env.example" }
}

function New-Certs {
    if (Test-Path "$CertsDir\root-ca.pem") { Ok "Certificados ya generados ($CertsDir)"; return }
    Info "Generando certificados TLS de Wazuh..."
    New-Item -ItemType Directory -Force -Path $CertsDir | Out-Null
    Compose --profile setup run --rm certs
    Ok "Certificados generados"
}

function Wait-Ready {
    $port = Get-EnvValue "DASHBOARD_PORT" "443"
    Info "Esperando a que Wazuh esté listo (la primera vez puede tardar 3-5 min)..."
    $probe = "curl -sk -o /dev/null -w '%{http_code}' https://wazuh.dashboard:5601/app/login | grep -q 200"
    for ($i = 1; $i -le 90; $i++) {
        & docker compose exec -T wazuh.manager sh -c $probe *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            $url = if ($port -eq "443") { "https://localhost" } else { "https://localhost:$port" }
            $pass = Get-EnvValue "INDEXER_PASSWORD" "SecretPassword"
            Ok "Wazuh listo"
@"

  +--------------------------------------------------------------+
    Dashboard:   $url
    Usuario:     admin
    Contraseña:  $pass
    (El navegador avisará del certificado autofirmado: acéptalo.)

    Siguiente paso:  .\lab.ps1 attacker   -> ataca srv-ssh y srv-web
                     .\lab.ps1 replay --list
  +--------------------------------------------------------------+

"@ | Write-Host
            return
        }
        Write-Host -NoNewline "."
        Start-Sleep -Seconds 10
    }
    Fail "Wazuh no responde. Revisa: .\lab.ps1 logs wazuh.dashboard"
}

function Invoke-Setup {
    Info "Instalando soc-lab"
    Test-Docker; Test-Memory; Initialize-Env; Set-MaxMapCount; New-Certs
    Info "Descargando y construyendo imágenes (la primera vez tarda unos minutos)..."
    Compose pull --ignore-buildable --quiet
    Compose build
    Compose --profile tools build replayer
    Compose up -d
    Wait-Ready
    Show-Status
}

function Invoke-Up {
    Test-Docker; Initialize-Env
    if (-not (Test-Path "$CertsDir\root-ca.pem")) { Warn "Primera vez: ejecuto 'setup'"; Invoke-Setup; return }
    Set-MaxMapCount
    # --build: si has hecho git pull, reconstruye la Kali y las víctimas (con caché, tarda segundos)
    Compose up -d --build
    Wait-Ready
}

function Show-Status {
    & docker compose ps --format 'table {{.Service}}\t{{.State}}\t{{.Status}}'
    Write-Host ""
    Info "Agentes Wazuh:"
    & docker compose exec -T wazuh.manager /var/ossec/bin/agent_control -l 2>$null | Select-String "ID:"
}

function Invoke-Reset {
    Warn "Esto borra TODAS las alertas, agentes y datos del laboratorio."
    $answer = Read-Host "¿Seguro? Escribe 'si' para continuar"
    if ($answer -ne "si") { Info "Cancelado."; return }
    Compose --profile tools down -v
    Ok "Datos borrados. Arranca de nuevo con .\lab.ps1 up"
}

switch ($Command.ToLower()) {
    "setup"    { Invoke-Setup }
    { $_ -in "up", "start" }   { Invoke-Up }
    { $_ -in "down", "stop" }  { Compose --profile tools down }
    { $_ -in "status", "ps" }  { Show-Status }
    { $_ -in "attacker", "kali" } { & docker compose exec attacker bash }
    "shell"    {
        if (-not $Rest) { Fail "Indica el servicio, p. ej.: .\lab.ps1 shell srv-ssh" }
        & docker compose exec $Rest[0] bash
    }
    "replay"   { & docker compose --profile tools run --rm replayer @Rest }
    "logs"     { & docker compose logs -f --tail 100 @Rest }
    "reset"    { Invoke-Reset }
    default    { Show-Usage }
}
