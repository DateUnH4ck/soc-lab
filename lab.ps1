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

# En Windows PowerShell 5.1, con $ErrorActionPreference = "Stop", cualquier
# línea que docker escriba en stderr (avisos, "Unable to find image"...) se
# convierte en un error que corta el script si se redirige. Estas dos funciones
# lo desactivan solo para esa llamada; el resultado se comprueba con $LASTEXITCODE.
function Invoke-DockerQuiet { $ErrorActionPreference = "Continue"; & docker @args *> $null }
function Invoke-DockerNoErr { $ErrorActionPreference = "Continue"; & docker @args 2>$null }
# git también escribe su progreso en stderr: mismo tratamiento.
function Invoke-Git      { $ErrorActionPreference = "Continue"; & git @args }
function Invoke-GitQuiet { $ErrorActionPreference = "Continue"; & git @args 2>$null }

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
    update            Actualiza el laboratorio a la última versión
                      (conserva alertas, agentes y certificados)
    version           Muestra la versión del laboratorio
    attacker          Abre una shell en la Kali atacante
    shell <servicio>  Abre una shell en un contenedor (srv-web, srv-ssh...)
    replay [args]     Reproduce ataques de Windows en Wazuh
                      (.\lab.ps1 replay --list  |  .\lab.ps1 replay dcsync)
    capture <servicio> [segundos]
                      Captura el tráfico de un contenedor (60 s por defecto)
                      en captures\*.pcap, para abrirlo con Wireshark
    turno             Simula un turno de N1: durante unos minutos pasa de
                      todo en la empresa y tú trabajas la cola en Wazuh
    logs [servicio]   Muestra los logs (Ctrl+C para salir)
    reset             Borra TODOS los datos (alertas, agentes) y empieza de cero
    help              Esta ayuda

"@ | Write-Host
}

function Test-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Fail "Docker no está instalado. Instala Docker Desktop: https://www.docker.com/products/docker-desktop/"
    }
    Invoke-DockerQuiet info
    if ($LASTEXITCODE -ne 0) { Fail "Docker no está arrancado. Abre Docker Desktop y vuelve a probar." }
    Invoke-DockerQuiet compose version
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
    Invoke-DockerQuiet run --rm --privileged alpine:3.20 sysctl -w vm.max_map_count=262144
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
        Invoke-DockerQuiet compose exec -T wazuh.manager sh -c $probe
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
    Compose --profile tools build replayer capture
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
    Invoke-DockerNoErr compose exec -T wazuh.manager /var/ossec/bin/agent_control -l | Select-String "ID:"
}

function Get-LabVersion {
    if (Test-Path VERSION) { return (Get-Content VERSION | Select-Object -First 1).Trim() }
    return "?"
}

function Test-GitRepo {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $false }
    $inside = Invoke-GitQuiet rev-parse --is-inside-work-tree
    return ($LASTEXITCODE -eq 0 -and "$inside" -eq "true")
}

function Show-Version {
    $extra = ""
    if (Test-GitRepo) {
        $commit = Invoke-GitQuiet rev-parse --short HEAD
        $fecha  = Invoke-GitQuiet log -1 --format=%cd --date=short
        $extra = " (commit $commit, $fecha)"
    }
    Write-Host "soc-lab $(Get-LabVersion)$extra"
}

function Invoke-Update {
    Test-Docker
    if (-not (Test-GitRepo)) {
        Fail "Esta carpeta no es un repositorio git (¿descargaste el ZIP?). Instálalo con 'git clone' (ver README) para poder actualizar con .\lab.ps1 update."
    }
    $cambios = @(Invoke-GitQuiet status --porcelain --untracked-files=no)
    if ($cambios.Count -gt 0 -and "$cambios".Trim()) {
        Warn "Has cambiado ficheros del laboratorio:"
        $cambios | ForEach-Object { Write-Host "    $_" }
        Fail "Guárdalos con 'git stash' (o descártalos con 'git checkout -- .') y vuelve a lanzar .\lab.ps1 update"
    }
    $before = Invoke-GitQuiet rev-parse HEAD
    $oldVer = Get-LabVersion
    Info "Descargando la última versión..."
    Invoke-Git pull --ff-only
    if ($LASTEXITCODE -ne 0) { Fail "No he podido actualizar con git pull. Revisa el mensaje de arriba." }
    $after = Invoke-GitQuiet rev-parse HEAD
    if ($before -eq $after) {
        Ok "Ya tenías la última versión del código: soc-lab $(Get-LabVersion)"
    } else {
        Ok "soc-lab $oldVer -> $(Get-LabVersion). Cambios:"
        Invoke-Git --no-pager log --oneline "$before..$after" | ForEach-Object { Write-Host "    $_" }
    }
    Initialize-Env
    if (-not (Test-Path "$CertsDir\root-ca.pem")) { Warn "No hay certificados: hago la instalación completa"; Invoke-Setup; return }
    Set-MaxMapCount
    Info "Reconstruyendo y arrancando (tus alertas, agentes y certificados se conservan)..."
    Compose --profile tools build replayer capture
    Compose up -d --build --remove-orphans
    if ($before -ne $after) {
        Invoke-GitQuiet diff --quiet $before $after -- wazuh/manager
        if ($LASTEXITCODE -ne 0) {
            Info "Han cambiado las reglas o la configuración de Wazuh: reinicio el manager"
            Compose restart wazuh.manager
        }
    }
    Wait-Ready
    Show-Status
    Ok "Laboratorio actualizado: soc-lab $(Get-LabVersion)"
}

function Invoke-Capture {
    if (-not $Rest) { Fail "Indica el servicio. Ejemplo: .\lab.ps1 capture srv-ssh 30" }
    $svc = $Rest[0]
    $secs = 60
    if ($Rest.Count -gt 1) {
        if ($Rest[1] -notmatch '^[0-9]+$' -or [int]$Rest[1] -lt 1) { Fail "Los segundos tienen que ser un número (p. ej. 30)" }
        $secs = [int]$Rest[1]
    }
    $cid = Invoke-DockerNoErr compose ps -q $svc
    if (-not $cid) { Fail "El servicio '$svc' no está arrancado. Mira los nombres con .\lab.ps1 status" }
    Invoke-DockerQuiet image inspect dateunh4ck/soc-lab-capture:local
    if ($LASTEXITCODE -ne 0) { Compose --profile tools build capture }
    New-Item -ItemType Directory -Force -Path captures | Out-Null
    $file = "$svc-$(Get-Date -Format 'yyyyMMdd-HHmmss').pcap"
    $dir = Join-Path (Get-Location).Path "captures"
    Info "Capturando el tráfico de $svc durante $secs s -> captures\$file"
    $ErrorActionPreference = "Continue"
    & docker run --rm --network "container:$cid" -v "${dir}:/captures" dateunh4ck/soc-lab-capture:local `
        sh -c "timeout -s INT $secs tcpdump -i any -n -U -w /captures/$file; exit 0"
    $ErrorActionPreference = "Stop"
    if (-not (Test-Path (Join-Path $dir $file))) { Fail "No se ha creado la captura. Revisa que Docker Desktop comparte esta carpeta." }
    Ok "Captura guardada en captures\$file (ábrela con Wireshark)"
}

function Invoke-Turno {
    $file = Join-Path $PSScriptRoot "tools\turno\pasos.txt"
    $pasos = @(Get-Content -Encoding UTF8 $file | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith("#") })
    Info "Empieza tu turno. Durante unos minutos van a pasar cosas en Hackerlab Logística."
    Info "No mires esta ventana: abre Wazuh (Threat Hunting) y trabaja la cola de alertas."
    $n = 0
    foreach ($linea in $pasos) {
        $partes = $linea.Split([char]'|', 3)
        if ($partes.Count -lt 3) { continue }
        $n++
        Start-Sleep -Seconds ([int]$partes[0])
        Write-Host -NoNewline "`r  actividad $n de $($pasos.Count) en marcha... "
        if ($partes[1] -eq "replay") {
            Invoke-DockerQuiet compose --profile tools run --rm replayer $partes[2]
        } else {
            Invoke-DockerQuiet compose exec -T $partes[1] sh -c $partes[2]
        }
    }
    Write-Host ""
    Ok "Se acabó la actividad. Tu turno sigue: termina la cola, abre los tickets y escribe la nota de relevo."
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
    "update"   { Invoke-Update }
    { $_ -in "version", "--version" } { Show-Version }
    "capture"  { Invoke-Capture }
    "turno"    { Invoke-Turno }
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
