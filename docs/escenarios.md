# Escenarios del replayer

Ataques reales de Windows/Active Directory que puedes reproducir en Wazuh (25 escenarios) con:

```bash
./lab.sh replay <escenario>        # Windows: .\lab.ps1 replay <escenario>
./lab.sh replay --list
./lab.sh replay --all
```

| Escenario | Qué pasó | ATT&CK | Módulo del curso | Alerta principal en Wazuh |
|---|---|---|---|---|
| `dcsync` | DCSync contra el controlador de dominio | T1003.006 | M3 · Active Directory | **100100** (nivel 12) · regla del lab |
| `password-spray` | Password spraying por Kerberos (4771) | T1110.003 | M3 · Active Directory | 60205 (nivel 10) · varios fallos de auditoría |
| `lsass-mimikatz` | Volcado de LSASS con Mimikatz (Sysmon 10) | T1003.001 | M6 · Logs y telemetría | **100101** (nivel 12) · regla del lab |
| `lsass-powershell` | Volcado de LSASS desde PowerShell (4104) | T1003.001 | M6 · Logs y telemetría | 91815 (nivel 4) |
| `pass-the-hash` | Pass-the-Hash con Mimikatz (4624 tipo 9) | T1550.002 | M3 · Active Directory | **100103** (nivel 12) · regla del lab |
| `psexec` | Movimiento lateral con PsExec | T1021.002 | M10 · Endpoint | 92027 / 92307 (nivel 3-4) |
| `wmiexec` | Ejecución remota con wmiexec (Impacket) | T1047 | M10 · Endpoint | 92106 (nivel 3) |
| `remote-service` | Creación remota de un servicio (7045) | T1543.003 | M6 · Logs y telemetría | 61138 (nivel 5) |
| `scheduled-task` | Persistencia con tarea programada | T1053.005 | M10 · Endpoint | **100104** y **100105** (nivel 8 y 10) · reglas del lab |
| `run-key` | Persistencia en clave Run oculta (Sysmon 13) | T1547.001 | M10 · Endpoint | **100102** (nivel 10) · regla del lab |
| `admin-group` | Cuenta añadida a Administradores (4732) | T1098 | M3 · Active Directory | 60154 (nivel 12) |
| `process-4688` | Proceso creado con PowerShell codificado (4688) | T1059.001 | M2 · Windows y Linux | 67027 (nivel 3) |
| `unquoted-service` | Servicio con ruta sin comillas (Sysmon 1 y 11) | T1574.009 | M2 · Windows y Linux | 61618 (nivel 12) y 92052 |
| `task-4698` | Tarea programada creada y borrada (4698 y 4699) | T1053.005 | M2 · Windows y Linux | 60228 (nivel 4) |
| `wmi-persistence` | Suscripción WMI con CommandLineEventConsumer (Sysmon 19-21) | T1546.003 | M2 · Windows y Linux | 89502 (nivel 14) |
| `powershell-4104` | Descarga con PowerShell (4103 y 4104) | T1059.001 | M2 · Windows y Linux | 91837 (nivel 4) |
| `uac-bypass` | Bypass de UAC con eventvwr.exe (Sysmon 13 y 1) | T1548.002 | M2 · Windows y Linux | **100130** (nivel 12) · regla del lab |
| `local-account` | Cuenta local creada y añadida a Administradores (Sysmon 12 y 13) | T1136.001 | M2 · Windows y Linux | **100131** y **100132** (nivel 10) · reglas del lab |
| `kerbrute` | Enumeración de usuarios por Kerberos (4768 y 4771) | T1087.002 | M3 · Active Directory | 60104 / 60205 y **100108** (TGT, nivel 3) |
| `ntlm-bruteforce` | Fuerza bruta por NTLM contra cuentas locales (4776 y 4625) | T1110.001 | M3 · Active Directory | 60122 (nivel 5) |
| `kerberoast` | Kerberoasting: ticket de servicio con RC4 (4769) | T1558.003 | M3 · Active Directory | **100106** (nivel 12) · regla del lab |
| `asrep-roast` | AS-REP roasting: TGT sin preautenticación (4768) | T1558.004 | M3 · Active Directory | **100107** (nivel 12) · regla del lab |
| `bloodhound` | Recolección de BloodHound (SAMR por IPC$, 5145) | T1087.002 | M3 · Active Directory | **100133** (nivel 8) · regla del lab |
| `dcsync-rights` | Permisos de DCSync concedidos con PowerView (5136 y 4662) | T1098 | M3 · Active Directory | **100134** (nivel 12) · regla del lab, y 60229 |
| `log-cleared` | Log de seguridad borrado (1102) | T1070.001 | M6 · Logs y telemetría | 63103 (nivel 5) |

Todos los escenarios generan alertas: la CI los reproduce uno a uno en x86 y ARM
en cada cambio (`tests/scenarios.sh`). Las reglas marcadas como *del lab* están en
[`wazuh/manager/local_rules.xml`](../wazuh/manager/local_rules.xml): Wazuh no trae
de serie una detección para esos ataques, y en el curso veremos cómo se escriben.
Algunas detecciones de serie tienen nivel bajo (3-5): mejorarlas también es parte
del curso (M14 · Detection engineering).

## Dónde ver los eventos

Los eventos llegan a Wazuh a través del manager, así que aparecen con el agente
`wazuh.manager`. El nombre del equipo Windows original está en
`data.win.system.computer`.

En el dashboard: **Threat Hunting** → `rule.groups: windows`.
Dentro de cada escenario, los eventos que no disparan ninguna regla con nivel ≥ 3
no generan alerta: eso también es una lección (no toda la telemetría se convierte
en alerta).

## Cómo funciona

`replayer/replay.py` lee los ficheros `.evtx`, convierte cada evento al mismo
XML que envía el agente de Windows y lo entrega en la cola interna del manager
(`queue/sockets/queue`) por el canal `EventChannel`. Las muestras se descargan de
[EVTX-ATTACK-SAMPLES](https://github.com/sbousseaden/EVTX-ATTACK-SAMPLES) (GPLv3) y de
[EVTX-to-MITRE-Attack](https://github.com/mdecrevoisier/EVTX-to-MITRE-Attack) (CC0),
con un commit fijado de cada una en `replayer/scenarios.yml`, y se guardan en caché.

Para añadir un escenario, añade una entrada en `replayer/scenarios.yml` (con
`source:` si la muestra viene de otra fuente).

Las reglas del lab de Kerberos y NTLM (**100108** TGT 4768 y **100109** validación
NTLM 4776) son telemetría de nivel 3: de serie Wazuh no guarda esos eventos y,
sin ellos, no se puede investigar un ataque a Active Directory.
