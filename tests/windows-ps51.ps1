# =============================================================================
#  Prueba de lab.ps1 en Windows PowerShell 5.1 (sin Docker)
#
#  En PowerShell 5.1, con $ErrorActionPreference = "Stop", cualquier línea que
#  un programa externo escriba en stderr se convierte en un error que corta el
#  script si se redirige. Eso rompía lab.ps1 en Windows (prueba del 9 nov 2026).
#  Aquí se comprueba, con un docker falso que escribe en stderr, que las
#  funciones Invoke-DockerQuiet e Invoke-DockerNoErr de lab.ps1 ya no se cortan.
#
#  Uso (en Windows PowerShell 5.1):  .\tests\windows-ps51.ps1
# =============================================================================
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$lab  = Join-Path $root "lab.ps1"
$fallos = 0

function Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Mal($m)  { Write-Host "[X]  $m" -ForegroundColor Red; $script:fallos++ }

Write-Host "PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"

# 1. Sintaxis de lab.ps1
$tokens = $null; $errores = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($lab, [ref]$tokens, [ref]$errores)
if ($errores.Count -gt 0) {
    $errores | ForEach-Object { Write-Host "  $_" }
    throw "lab.ps1 tiene errores de sintaxis"
}
Ok "Sintaxis de lab.ps1"

# 2. Cargar solo las funciones auxiliares (sin ejecutar el script)
$nombres = "Invoke-DockerQuiet", "Invoke-DockerNoErr"
$funciones = $ast.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $nombres -contains $n.Name
}, $true)
if ($funciones.Count -ne $nombres.Count) { throw "No encuentro $($nombres -join ' y ') en lab.ps1" }
foreach ($f in $funciones) { . ([scriptblock]::Create($f.Extent.Text)) }
Ok "Funciones cargadas: $($nombres -join ', ')"

# 3. docker falso: una línea en stdout, otra en stderr y el código de salida de FAKE_EXIT
$dir = Join-Path ([System.IO.Path]::GetTempPath()) "soc-lab-fake-docker"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Set-Content -Path (Join-Path $dir "docker.cmd") -Encoding Ascii -Value @(
    "@echo off",
    "echo    ID: 000, Name: wazuh.manager (server), IP: 127.0.0.1, Active/Local",
    "echo Unable to find image 'alpine:3.20' locally 1>&2",
    "exit /b %FAKE_EXIT%"
)
$env:PATH = "$dir;$env:PATH"

# 4. Control: el patrón antiguo tiene que cortar el script en este PowerShell
$env:FAKE_EXIT = "0"
$corta = $false
try { & docker info *> $null } catch { $corta = $true }
if ($corta) { Ok "Control: el patrón antiguo (& docker ... *> `$null) corta el script, como en Windows" }
else        { Mal "Control: el patrón antiguo no corta el script; esta prueba no reproduce el fallo" }

# 5. Invoke-DockerQuiet con éxito
$env:FAKE_EXIT = "0"
try {
    Invoke-DockerQuiet run --rm alpine:3.20 true
    if ($LASTEXITCODE -eq 0) { Ok "Invoke-DockerQuiet: stderr ignorado y código 0" }
    else { Mal "Invoke-DockerQuiet: código $LASTEXITCODE, esperaba 0" }
} catch { Mal "Invoke-DockerQuiet (éxito) ha cortado el script: $_" }

# 6. Invoke-DockerQuiet con fallo: no corta, pero el código de salida se conserva
$env:FAKE_EXIT = "1"
try {
    Invoke-DockerQuiet info
    if ($LASTEXITCODE -eq 1) { Ok "Invoke-DockerQuiet: un fallo de docker se detecta por el código de salida (1)" }
    else { Mal "Invoke-DockerQuiet: código $LASTEXITCODE, esperaba 1" }
} catch { Mal "Invoke-DockerQuiet (fallo) ha cortado el script: $_" }

# 7. Invoke-DockerNoErr: conserva stdout para Select-String
$env:FAKE_EXIT = "0"
try {
    $lineas = @(Invoke-DockerNoErr compose exec -T wazuh.manager /var/ossec/bin/agent_control -l | Select-String "ID:")
    if ($lineas.Count -eq 1) { Ok "Invoke-DockerNoErr: stdout conservado y stderr ignorado" }
    else { Mal "Invoke-DockerNoErr: $($lineas.Count) líneas con 'ID:', esperaba 1" }
} catch { Mal "Invoke-DockerNoErr ha cortado el script: $_" }

Remove-Item -Recurse -Force $dir
if ($fallos -gt 0) { Write-Host "$fallos prueba(s) fallida(s)" -ForegroundColor Red; exit 1 }
Write-Host "Todas las pruebas de lab.ps1 en PowerShell 5.1 han pasado" -ForegroundColor Green
