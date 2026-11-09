# Instalación en Windows

Probado en Windows 11 x64 con Docker Desktop (backend WSL 2) y Windows
PowerShell 5.1, el que viene de serie. En un portátil sin nada instalado, el
proceso completo lleva unos 30 minutos, de los que el setup son unos 10.

Necesitas una cuenta de **administrador** del PC (o su contraseña) para
instalar WSL y Docker Desktop.

## 1. Instala WSL

Docker Desktop funciona sobre WSL 2, el subsistema de Linux de Windows.
Abre **Terminal (Administrador)** o **PowerShell (Administrador)**: clic derecho
en el botón de Inicio. Ejecuta:

```powershell
wsl --install --no-distribution
```

Con `--no-distribution` se instala solo lo que necesita Docker, sin descargar
Ubuntu. **Reinicia el PC** cuando termine: sin reiniciar, Docker no arranca.

## 2. Instala Docker Desktop

1. Descárgalo de https://www.docker.com/products/docker-desktop/ e instálalo.
2. Si el instalador te pregunta el tipo de instalación, elige
   **All-users installation**. La instalación *per-user* no puede activar la
   *Plataforma de máquina virtual* de Windows y falla con
   *"One prerequisite is not fulfilled"*.
3. Deja marcada la opción **Use WSL 2**.
4. Abre Docker Desktop y espera a que abajo a la izquierda ponga
   **Engine running**. Puedes saltarte el inicio de sesión.

## 3. Instala Git

Desde PowerShell:

```powershell
winget install --id Git.Git -e --source winget
```

O descárgalo de https://git-scm.com/download/win con las opciones por defecto.
**Cierra PowerShell y abre uno nuevo**: hasta entonces no reconoce el comando
`git`. Compruébalo con `git --version`.

## 4. Descarga e instala el laboratorio

En PowerShell (no hace falta que sea como administrador):

```powershell
docker --version
git clone https://github.com/DateUnH4ck/soc-lab.git
cd soc-lab
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\lab.ps1 setup
```

`Set-ExecutionPolicy` solo hace falta la primera vez: permite ejecutar scripts
locales como `lab.ps1`. Clona el repositorio con git en lugar de descargarlo
como ZIP: Windows bloquea los scripts que vienen en un ZIP descargado.

Al terminar verás **Wazuh listo**, un recuadro con la dirección, el usuario y
la contraseña, y la tabla de estado. Si la tabla de agentes sale vacía, espera
un minuto y ejecuta `.\lab.ps1 status`: el manager acaba de arrancar.

## 5. Entra en Wazuh

Abre https://localhost (usuario `admin`, contraseña `SecretPassword`) y acepta
el aviso del certificado (Configuración avanzada › Continuar).

## Alternativa: desde WSL (Ubuntu)

Si ya usas WSL con una distribución, también puedes clonar el repositorio
dentro de Ubuntu (`~/soc-lab`) y usar `./lab.sh setup`. Suele ir más rápido que
trabajar sobre `C:\`, porque los ficheros están en el sistema de archivos de Linux.

## Problemas típicos

- **"Installation failed. One prerequisite is not fulfilled"** al instalar
  Docker Desktop: vuelve a ejecutar el instalador y elige *All-users
  installation*, o haz el paso 1 y reinicia.
- **"Docker Desktop - WSL not installed"**: haz el paso 1 (`wsl --install
  --no-distribution` como administrador) y reinicia.
- **`git` no se reconoce**: instálalo (paso 3) y abre un PowerShell nuevo.
- **"Docker no está arrancado"** o un error con `dockerDesktopLinuxEngine`:
  abre Docker Desktop y espera a **Engine running**.
- **Un error rojo de PowerShell (`NativeCommandError`)** durante el setup:
  actualiza el laboratorio con `git pull` y vuelve a ejecutar `.\lab.ps1 setup`.
  Si sigue saliendo, abre un issue con la captura.
- **"El puerto 443 ya está en uso"** (Skype, IIS, VPNs...): pon `DASHBOARD_PORT=8443`
  en `.env` y entra en https://localhost:8443
- **Docker Desktop no arranca y habla de virtualización**: en el Administrador
  de tareas › Rendimiento › CPU, mira si *Virtualización* está *Habilitada*. Si
  no, actívala en la BIOS (Intel VT-x, AMD SVM o *Virtualization Technology*).

## Desinstalar

```powershell
.\lab.ps1 reset
cd ..
Remove-Item -Recurse -Force soc-lab
Set-ExecutionPolicy -Scope CurrentUser Undefined
```

Y, si no vas a usarlo para otra cosa, desinstala Docker Desktop desde
Configuración › Aplicaciones.
