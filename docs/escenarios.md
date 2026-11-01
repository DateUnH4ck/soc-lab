# Escenarios del replayer

Ataques reales de Windows/Active Directory que puedes reproducir en Wazuh con:

```bash
./lab.sh replay <escenario>        # Windows: .\lab.ps1 replay <escenario>
./lab.sh replay --list
./lab.sh replay --all
```

| Escenario | Qué pasó | ATT&CK | Módulo del curso |
|---|---|---|---|
| `dcsync` | DCSync contra el controlador de dominio | T1003.006 | M3 · Active Directory |
| `password-spray` | Password spraying por Kerberos (4771) | T1110.003 | M3 · Active Directory |
| `lsass-mimikatz` | Volcado de LSASS con Mimikatz (Sysmon 10) | T1003.001 | M6 · Logs y telemetría |
| `lsass-powershell` | Volcado de LSASS desde PowerShell (4104) | T1003.001 | M6 · Logs y telemetría |
| `pass-the-hash` | Pass-the-Hash con Mimikatz (4624 tipo 9) | T1550.002 | M3 · Active Directory |
| `psexec` | Movimiento lateral con PsExec | T1021.002 | M10 · Endpoint |
| `wmiexec` | Ejecución remota con wmiexec (Impacket) | T1047 | M10 · Endpoint |
| `remote-service` | Creación remota de un servicio (7045) | T1543.003 | M6 · Logs y telemetría |
| `scheduled-task` | Persistencia con tarea programada | T1053.005 | M10 · Endpoint |
| `run-key` | Persistencia en clave Run oculta (Sysmon 13) | T1547.001 | M10 · Endpoint |
| `admin-group` | Cuenta añadida a Administradores (4732) | T1098 | M3 · Active Directory |

## Dónde ver los eventos

Los eventos llegan a Wazuh a través del manager, así que aparecen con el agente
`wazuh.manager`. El nombre del equipo Windows original está en
`data.win.system.computer`.

En el dashboard: **Threat Hunting** → `rule.groups: windows`.
Los eventos que no disparan ninguna regla con nivel ≥ 3 no generan alerta:
eso también es una lección (no toda la telemetría se convierte en alerta).

## Cómo funciona

`replayer/replay.py` lee los ficheros `.evtx`, convierte cada evento al mismo
XML que envía el agente de Windows y lo entrega en la cola interna del manager
(`queue/sockets/queue`) por el canal `EventChannel`. Las muestras se descargan de
[EVTX-ATTACK-SAMPLES](https://github.com/sbousseaden/EVTX-ATTACK-SAMPLES)
(commit fijado en `replayer/scenarios.yml`) y se guardan en caché.

Para añadir un escenario, añade una entrada en `replayer/scenarios.yml`.
