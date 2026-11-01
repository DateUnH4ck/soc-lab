# Instalación en Mac

Funciona en Mac con Apple Silicon (M1, M2, M3, M4...) y en Mac con Intel.
Todas las imágenes del laboratorio tienen versión ARM64 nativa: no hay emulación.

1. **Instala Docker Desktop for Mac** (versión Apple Silicon o Intel según tu Mac):
   https://www.docker.com/products/docker-desktop/
2. En Docker Desktop: **Settings → Resources → Memory → 8 GB** → *Apply & restart*.
3. Abre la Terminal:

   ```bash
   git clone https://github.com/DateUnH4ck/soc-lab.git
   cd soc-lab
   ./lab.sh setup
   ```

4. Abre https://localhost (usuario `admin`, contraseña `SecretPassword`).
   Safari a veces no deja aceptar el certificado autofirmado: usa Chrome,
   Brave o Firefox.

## Alternativas a Docker Desktop

También funciona con [OrbStack](https://orbstack.dev/) o
[Colima](https://github.com/abiosoft/colima) (`colima start --cpu 4 --memory 8`).
