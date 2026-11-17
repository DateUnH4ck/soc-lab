<h1 align="center">soc-lab</h1>
<p align="center"><b>El laboratorio SOC del curso "De 0 a Analista SOC N2"</b><br>
de <a href="https://www.youtube.com/@DateUnH4ck">@DateUnH4ck</a> · en español · gratis</p>

<p align="center">
  <a href="../../actions/workflows/ci.yml"><img src="../../actions/workflows/ci.yml/badge.svg" alt="CI x86, ARM y Windows"></a>
  <img src="https://img.shields.io/badge/x86__64-PC%20Windows%20%2F%20Linux-0078D6?style=flat-square" alt="x86_64">
  <img src="https://img.shields.io/badge/ARM64-Mac%20Apple%20Silicon-000000?style=flat-square&logo=apple" alt="ARM64">
  <img src="https://img.shields.io/badge/SIEM-Wazuh%204.14-3C99DC?style=flat-square" alt="Wazuh">
</p>

---

Un SOC en miniatura que se monta con **un comando** en tu ordenador, tengas un PC
con Windows o un Mac con Apple Silicon. Lo usamos en todos los episodios del
curso: atacas desde una Kali, y luego investigas lo que ha pasado desde el SIEM,
como harías en un SOC de verdad.

```
                  red soc (172.30.20.0/24)
   ┌──────────────────────────────────────────────────────┐
   │   Wazuh indexer ◄── Wazuh manager ──► Wazuh dashboard │ ◄── tú (https://localhost)
   │                        ▲     ▲                        │
   └────────────────────────┼─────┼────────────────────────┘
                     agente │     │ agente          ▲
   ┌────────────────────────┼─────┼────────────┐    │ replayer: ataques reales
   │   srv-web (nginx) ─────┘     └─── srv-ssh │    │ de Windows / AD (EVTX)
   │   172.30.10.10                172.30.10.11│
   │            ▲                      ▲       │
   │            └──── kali (atacante) ─┘       │
   │                  172.30.10.66             │
   │                  │ DNS          │ web     │
   │                  ▼              ▼         │
   │   srv-dns (dnsmasq)    srv-proxy (Squid)  │──► agentes ──► Wazuh
   │   172.30.10.53         172.30.10.8        │
   └───────────────────────────────────────────┘
                  red dmz (172.30.10.0/24)
```

## Qué incluye (versión 1.2)

| Pieza | Qué es | Para qué la usamos |
|---|---|---|
| **Wazuh 4.14** | SIEM + XDR open source (indexer, manager y dashboard) | Ver alertas, buscar en logs, investigar |
| **srv-web** | Servidor nginx (HTTP y HTTPS) con agente Wazuh | Escaneos web, TLS y SNI en el log, defacement (FIM) |
| **srv-ssh** | Servidor Linux con OpenSSH, sudo y cron, con agente Wazuh | Fuerza bruta SSH, accesos, sudo, persistencia (cron, claves SSH) |
| **srv-dns** | DNS de la empresa (dnsmasq, zona `hackerlab.local`) con agente Wazuh | Ver cada consulta DNS en el SIEM, túneles DNS |
| **srv-proxy** | Proxy de salida de la empresa (Squid) con agente Wazuh | Registro de navegación, X-Forwarded-For |
| **kali** | Kali Linux con nmap, hydra, nikto... | Atacar a las víctimas (solo dentro del lab) |
| **replayer** | Inyecta en Wazuh eventos reales de ataques a Windows (25 escenarios) | Practicar Active Directory y Sysmon **sin una VM Windows** |
| **Reglas propias** | Detecciones que Wazuh no trae de serie (p. ej. DCSync) | Que todos los ataques del curso generen alerta desde el primer día |

## Requisitos

- **Docker Desktop** (Windows o Mac) o Docker Engine + Compose v2 (Linux).
- **8 GB de RAM** asignados a Docker (mínimo 6) y unos 20 GB de disco.
- Funciona en **x86_64** y **ARM64**: la CI lo prueba en las dos en cada cambio.

Guías paso a paso: [Windows](docs/windows.md) · [Mac](docs/mac.md) · [Linux](docs/linux.md) · [requisitos y memoria](docs/requisitos.md)

## Instalación

```bash
git clone https://github.com/DateUnH4ck/soc-lab.git
cd soc-lab
```

**Mac / Linux**

```bash
./lab.sh setup
```

**Windows (PowerShell)**

```powershell
.\lab.ps1 setup
```

La primera vez tarda entre 5 y 15 minutos (descarga de imágenes). Al terminar verás:

```
Dashboard:   https://localhost
Usuario:     admin
Contraseña:  SecretPassword
```

El navegador avisará de que el certificado es autofirmado: es normal, acéptalo.

## Uso

| Mac / Linux | Windows | Qué hace |
|---|---|---|
| `./lab.sh up` | `.\lab.ps1 up` | Arranca el laboratorio |
| `./lab.sh down` | `.\lab.ps1 down` | Lo para (conserva alertas y agentes) |
| `./lab.sh status` | `.\lab.ps1 status` | Estado de contenedores y agentes |
| `./lab.sh attacker` | `.\lab.ps1 attacker` | Shell en la Kali |
| `./lab.sh shell srv-ssh` | `.\lab.ps1 shell srv-ssh` | Shell en una víctima |
| `./lab.sh replay --list` | `.\lab.ps1 replay --list` | Lista los ataques de Windows disponibles |
| `./lab.sh replay dcsync` | `.\lab.ps1 replay dcsync` | Reproduce un ataque en Wazuh |
| `./lab.sh capture srv-ssh 30` | `.\lab.ps1 capture srv-ssh 30` | Captura 30 s de tráfico en `captures/` (para Wireshark) |
| `./lab.sh turno` | `.\lab.ps1 turno` | Simula un turno de N1: unos minutos de actividad para triar en Wazuh |
| `./lab.sh logs srv-web` | `.\lab.ps1 logs srv-web` | Logs de un servicio |
| `./lab.sh update` | `.\lab.ps1 update` | Actualiza el laboratorio a la última versión |
| `./lab.sh version` | `.\lab.ps1 version` | Versión que tienes instalada |
| `./lab.sh reset` | `.\lab.ps1 reset` | Borra todos los datos y empieza de cero |

## Actualizar el laboratorio

El laboratorio crece con el curso: algunos episodios necesitan piezas nuevas.
Si ya lo tenías instalado, no hace falta borrarlo ni instalarlo otra vez:

```bash
./lab.sh update        # Windows: .\lab.ps1 update
```

Descarga la última versión, reconstruye lo que haya cambiado y lo arranca.
**Conserva tus alertas, tus agentes y tus certificados.** Al terminar te dice de
qué versión a qué versión has pasado y qué ha cambiado ([CHANGELOG.md](CHANGELOG.md)).

- Cada episodio indica en su página de [curso-analista-soc](https://github.com/DateUnH4ck/curso-analista-soc)
  qué versión del laboratorio necesita. Mira la tuya con `./lab.sh version`.
- Si has cambiado algún fichero del laboratorio, `update` se para y te lo dice:
  guarda tus cambios con `git stash` (o descártalos con `git checkout -- .`) y repite.
- Si lo descargaste como ZIP en lugar de con `git clone`, `update` no funciona:
  vuelve a instalarlo con `git clone` (sección *Instalación*).
- ¿Tienes una versión de antes de la 1.1 (sin `update`)? Hazlo una vez a mano:
  `git pull` y después `./lab.sh update`.

## Tu primer ataque (y tu primera alerta)

```bash
./lab.sh attacker
# ya dentro de la Kali:
# el prompt cambia a «kali ☠ atacante», en rojo: estás en la Kali
hydra -t 4 -l soporte -P ~/wordlists/passwords.txt ssh://172.30.10.11
# 17 contraseñas: en unos segundos encuentra soporte / sunshine
exit   # vuelves a tu ordenador
```

Vete al dashboard → **Threat Hunting** → filtra por `agent.name: srv-ssh`
(si ves el aviso *Lucene syntax warning*, pulsa *Don't show again*: la búsqueda es correcta).
Verás los intentos fallidos, la alerta de fuerza bruta y... el inicio de sesión
que lo consiguió. Eso es lo que tendrías que escalar en un SOC.

## Ataques de Windows sin Windows

El replayer reproduce en Wazuh eventos **reales** grabados durante ataques
(DCSync, Kerberoasting, Pass-the-Hash, PsExec, volcado de LSASS...) de los proyectos
[EVTX-ATTACK-SAMPLES](https://github.com/sbousseaden/EVTX-ATTACK-SAMPLES) y
[EVTX-to-MITRE-Attack](https://github.com/mdecrevoisier/EVTX-to-MITRE-Attack).
Llegan a Wazuh exactamente igual que si los enviara un agente de Windows, así
que saltan las mismas reglas. Todos los alumnos ven los mismos eventos.

```bash
./lab.sh replay dcsync
```

Dashboard → **Threat Hunting** → `rule.groups: windows`. Aparecen con el agente
`wazuh.manager`, porque entran por el manager y no por un agente de Windows.
El DCSync salta con una regla propia del laboratorio (`rule.id: 100100`, nivel 12):
Wazuh no lo detecta de serie, y en el curso veremos cómo se escribe una regla así.

Catálogo completo: [docs/escenarios.md](docs/escenarios.md)

## El DNS de la empresa

srv-dns es el DNS interno de Hackerlab Logística: la Kali y los servidores le
preguntan a él, y cada consulta llega a Wazuh.

```bash
./lab.sh attacker
dig srv-web.hackerlab.local      # nombres internos de la empresa
dig MX hackerlab.local           # registros de correo, TXT (SPF), PTR...
dig -x 172.30.10.11              # resolución inversa
```

Dashboard → **Threat Hunting** → `agent.name: srv-dns`. Cada consulta es una alerta
de nivel 3 (`rule.id: 100111`) y cada respuesta otra (`100112`): en Wazuh, lo que no
genera alerta no se guarda. Encima van dos detecciones del laboratorio: subdominio
muy largo (`100113`) y ráfaga de consultas desde un mismo equipo (`100114`), las
huellas típicas de un túnel DNS. El dominio `malo.test` hace de dominio del
atacante: cualquier subdominio suyo resuelve a la Kali.

## El proxy de la empresa

srv-proxy es el proxy de salida (Squid, puerto 3128). Lo que se navega a través
de él queda en su log y llega a Wazuh (`agent.name: srv-proxy`, `rule.id: 100120`).

```bash
./lab.sh attacker
curl -x http://srv-proxy.hackerlab.local:3128 http://srv-web.hackerlab.local/
curl -sk https://srv-web.hackerlab.local/          # HTTPS directo
```

Fíjate en el log de srv-web: cuando la petición llega por el proxy, la IP que
aparece es la del proxy, y la del equipo real va en `xff=` (X-Forwarded-For).
En HTTPS, el log añade la versión de TLS (`tls=`) y el nombre pedido (`sni=`).

## Un turno de N1

```bash
./lab.sh turno        # Windows: .\lab.ps1 turno
```

Durante unos minutos pasan cosas en la empresa: ataques, cambios legítimos de los
administradores y ruido. Tú trabajas la cola en Wazuh: separas lo real de lo
benigno, escalas lo que toca y escribes la nota de relevo. No mires
`tools/turno/pasos.txt` antes de hacerlo: es la solución.

## Cosas que conviene saber

- **Dos IPs por servidor.** srv-web, srv-ssh, srv-dns y srv-proxy tienen dos tarjetas de red: una en la
  DMZ (172.30.10.x), por donde las ataca la Kali, y otra en la red `soc`
  (172.30.20.x), por donde hablan con Wazuh. Por eso en el dashboard verás
  srv-ssh como 172.30.20.x aunque lo ataques en 172.30.10.11.
- **Horas en UTC.** La Kali y los logs van en UTC; tu ordenador y el dashboard,
  en tu hora local. Convertir zonas horarias es parte del trabajo en un SOC.
- **Para actualizar**, usa `./lab.sh update` (ver *Actualizar el laboratorio*).
- **Busca los agentes por nombre** (`agent.name: srv-ssh`), no por número: el ID
  puede cambiar entre instalaciones.
- La primera vez que abres el dashboard, el resumen de agentes puede tardar un
  par de minutos en actualizarse. Recarga la página.

## Seguridad

- Todos los puertos se publican solo en `127.0.0.1`: nadie de tu red puede entrar.
- Las víctimas tienen contraseñas débiles **a propósito**, y solo son accesibles
  desde la red interna del laboratorio.
- Las credenciales de Wazuh son las de serie. Es un laboratorio: no lo expongas
  a internet ni lo uses para datos reales.
- Ataca **solo** a las máquinas de este laboratorio.

## Hoja de ruta del laboratorio

- [x] **Fase 1** · Wazuh + víctimas Linux + Kali + replayer de Windows (temporadas 1-2)
- [x] **1.1** · DNS de la empresa (srv-dns), capturas de tráfico y `update`
- [x] **1.2** · HTTPS, proxy (srv-proxy), 25 escenarios de Windows/AD, cron y `turno` (temporada 1 completa)
- [ ] **Fase 2** · Phishing y CTI: Mailpit, MISP, TheHive + Cortex, CyberChef
- [ ] **Fase 3** · Red, endpoint e IR: Suricata, Zeek, Velociraptor, Elastic, VM Windows opcional
- [ ] **Fase 4** · Detección y automatización: Sigma, Atomic Red Team, Shuffle SOAR

## ¿Problemas?

Mira [docs/troubleshooting.md](docs/troubleshooting.md). Si no se soluciona,
abre un [issue](../../issues) indicando tu sistema operativo, arquitectura
y la salida de `./lab.sh status`.

## Créditos y licencia

- Configuración de Wazuh basada en [wazuh/wazuh-docker](https://github.com/wazuh/wazuh-docker) (GPLv2).
- Muestras de ataques: [EVTX-ATTACK-SAMPLES](https://github.com/sbousseaden/EVTX-ATTACK-SAMPLES)
  de Samir Bousseaden (GPLv3) y [EVTX-to-MITRE-Attack](https://github.com/mdecrevoisier/EVTX-to-MITRE-Attack)
  de Michel de Crevoisier (CC0); se descargan bajo demanda, no se incluyen en este repo.
- El resto del código: licencia MIT. Detalles en [NOTICE](NOTICE).

Hecho por **Jonathas Carneiro** · [YouTube](https://www.youtube.com/@DateUnH4ck) · [GitHub](https://github.com/dat3unh4ck)
