# Instalación en Linux

Linux es donde más se prueba el laboratorio: la CI lo levanta entero en
Ubuntu 24.04 (x86_64 y ARM64) en cada cambio. Funciona en cualquier
distribución con **Docker Engine** y el plugin **Docker Compose v2**.

## 1. Instala Docker Engine y Compose v2

**Ubuntu, Debian, Linux Mint y derivadas** (script oficial de Docker):

```bash
curl -fsSL https://get.docker.com | sudo sh
```

Instala Docker Engine y el plugin `docker compose` desde el repositorio de
Docker. Si prefieres hacerlo paso a paso, o usas Fedora, Arch u otra
distribución, sigue la guía oficial: https://docs.docker.com/engine/install/

> El paquete `docker.io` de algunas distribuciones no trae `docker compose`
> (v2), solo el antiguo `docker-compose`. soc-lab necesita v2: comprueba en el
> paso 3 que `docker compose version` funciona.

Arranca Docker y haz que se inicie con el sistema:

```bash
sudo systemctl enable --now docker
```

## 2. Usa Docker sin sudo

Añade tu usuario al grupo `docker`:

```bash
sudo usermod -aG docker $USER
```

**Cierra sesión y vuelve a entrar** (o reinicia) para que se aplique. Si no,
`./lab.sh` te dirá que tu usuario no tiene permiso para usar Docker.

> Estar en el grupo `docker` equivale a tener permisos de root en ese equipo.
> Es lo normal en un equipo personal de laboratorio; en un servidor compartido,
> usa `sudo ./lab.sh ...` en su lugar.

## 3. Comprueba la instalación

```bash
docker --version
docker compose version
docker run --rm hello-world
```

## 4. Descarga e instala el laboratorio

```bash
sudo apt install -y git        # si no lo tienes (en Fedora: sudo dnf install git)
git clone https://github.com/DateUnH4ck/soc-lab.git
cd soc-lab
./lab.sh setup
```

Al terminar verás **Wazuh listo**, un recuadro con la dirección, el usuario y la
contraseña, y la tabla de estado.

## 5. Entra en Wazuh

Abre https://localhost (usuario `admin`, contraseña `SecretPassword`) y acepta
el aviso del certificado autofirmado.

## Diferencias con Windows y Mac

- **Memoria:** no hay nada que configurar. Docker usa directamente la RAM del
  equipo; con 8 GB libres va bien (ver [requisitos](requisitos.md)).
- **`vm.max_map_count`:** el indexer necesita este ajuste del kernel. En Linux se
  aplica a tu propio equipo y se pierde al reiniciar; `./lab.sh up` lo vuelve a
  poner. No cambia nada de forma permanente.
- **Certificados:** la carpeta `wazuh/certs/` la crea un contenedor y queda a
  nombre de root. Para borrarla (regenerar certificados) hace falta `sudo`.
- **Docker Desktop for Linux:** también funciona. En ese caso la memoria se
  ajusta en Settings → Resources, como en Mac.

## Problemas típicos

- **"Tu usuario no tiene permiso para usar Docker"** (o `permission denied ...
  docker.sock`): haz el paso 2 y vuelve a iniciar sesión.
- **"Docker no está arrancado"**: `sudo systemctl start docker`.
- **"Falta Docker Compose v2"**: instala el plugin `docker-compose-plugin` desde
  el repositorio de Docker (paso 1).
- **El puerto 443 está ocupado** (un nginx o Apache local...): pon
  `DASHBOARD_PORT=8443` en `.env` y entra en https://localhost:8443
- Más en [troubleshooting](troubleshooting.md).

## Desinstalar

```bash
./lab.sh reset
cd ..
sudo rm -rf soc-lab
```

`sudo` hace falta por la carpeta de certificados. Las imágenes descargadas se
borran con `docker image prune -a` (borra también las de otros proyectos que
no estés usando).
