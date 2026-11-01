# Instalación en Windows

Probado con Windows 10/11 x64 y Docker Desktop (backend WSL2).

1. **Instala Docker Desktop**: https://www.docker.com/products/docker-desktop/
   En la instalación deja marcada la opción *Use WSL 2*. Reinicia si te lo pide.
2. **Instala Git**: https://git-scm.com/download/win (opciones por defecto).
3. Abre **PowerShell** y descarga el laboratorio:

   ```powershell
   git clone https://github.com/DateUnH4ck/soc-lab.git
   cd soc-lab
   ```

4. Si es la primera vez que ejecutas scripts en PowerShell:

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

5. Instala y arranca:

   ```powershell
   .\lab.ps1 setup
   ```

6. Abre https://localhost (usuario `admin`, contraseña `SecretPassword`).

## Alternativa: desde WSL (Ubuntu)

Si ya usas WSL, también puedes clonar el repositorio dentro de Ubuntu
(`~/soc-lab`) y usar `./lab.sh setup`. Suele ir más rápido que trabajar sobre
`C:\`, porque los ficheros están en el sistema de archivos de Linux.

## Problemas típicos

- **"El puerto 443 ya está en uso"** (Skype, IIS, VPNs...): pon `DASHBOARD_PORT=8443`
  en `.env` y entra en https://localhost:8443
- **Docker Desktop no arranca**: activa la virtualización en la BIOS y la
  característica *Plataforma de máquina virtual* de Windows.
