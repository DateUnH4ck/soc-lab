# Solución de problemas

**Lo primero:** `./lab.sh status` (Windows: `.\lab.ps1 status`) y
`./lab.sh logs <servicio>`.

### Windows: falla la instalación de Docker o de WSL, o `lab.ps1` da un error rojo
Mira la sección de problemas típicos de la [guía de Windows](windows.md).

### El dashboard dice "Wazuh dashboard server is not ready yet"
Es normal durante los primeros minutos. Espera 2-3 minutos y recarga.

### El indexer se reinicia en bucle
Casi siempre es memoria o `vm.max_map_count`:
- Da más RAM a Docker (ver [requisitos](requisitos.md)).
- Vuelve a ejecutar `./lab.sh up`, que reajusta `vm.max_map_count`
  (Docker Desktop lo pierde al reiniciarse).

### "port is already allocated" / el puerto 443 está ocupado
Cambia `DASHBOARD_PORT=8443` en `.env` y ejecuta `./lab.sh up`.

### Los agentes aparecen como "Disconnected" o "Never connected"
- Espera 1-2 minutos tras arrancar.
- Reinicia la víctima: `docker compose restart srv-ssh`.

### Quiero empezar de cero
`./lab.sh reset` borra alertas, agentes y datos. Los certificados se conservan.
Para regenerarlos también, borra la carpeta `wazuh/certs/`
(en Linux puede requerir `sudo`) y ejecuta `./lab.sh setup`.

### Cambiar las contraseñas de Wazuh
Las contraseñas de serie están fijadas por hashes en
`wazuh/indexer/internal_users.yml`. Para cambiarlas sigue la guía oficial:
https://documentation.wazuh.com/current/deployment-options/docker/wazuh-container.html#change-the-password-of-wazuh-users
y actualiza después los valores de `.env`.

### Mi problema no está aquí
Abre un issue con: sistema operativo, arquitectura (`docker info --format '{{.Architecture}}'`),
la salida de `./lab.sh status` y los logs del servicio que falla.
