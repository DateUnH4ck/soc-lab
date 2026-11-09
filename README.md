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
   └───────────────────────────────────────────┘
                  red dmz (172.30.10.0/24)
```

## Qué incluye (fase 1)

| Pieza | Qué es | Para qué la usamos |
|---|---|---|
| **Wazuh 4.14** | SIEM + XDR open source (indexer, manager y dashboard) | Ver alertas, buscar en logs, investigar |
| **srv-web** | Servidor nginx con agente Wazuh | Escaneos web, fuerza bruta, defacement (FIM) |
| **srv-ssh** | Servidor Linux con OpenSSH y agente Wazuh | Fuerza bruta SSH, accesos, persistencia |
| **kali** | Kali Linux con nmap, hydra, nikto... | Atacar a las víctimas (solo dentro del lab) |
| **replayer** | Inyecta en Wazuh eventos reales de ataques a Windows | Practicar Active Directory y Sysmon **sin una VM Windows** |
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
| `./lab.sh logs srv-web` | `.\lab.ps1 logs srv-web` | Logs de un servicio |
| `./lab.sh reset` | `.\lab.ps1 reset` | Borra todos los datos y empieza de cero |

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
(DCSync, Pass-the-Hash, PsExec, volcado de LSASS...) del proyecto
[EVTX-ATTACK-SAMPLES](https://github.com/sbousseaden/EVTX-ATTACK-SAMPLES).
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

## Cosas que conviene saber

- **Dos IPs por víctima.** srv-web y srv-ssh tienen dos tarjetas de red: una en la
  DMZ (172.30.10.x), por donde las ataca la Kali, y otra en la red `soc`
  (172.30.20.x), por donde hablan con Wazuh. Por eso en el dashboard verás
  srv-ssh como 172.30.20.x aunque lo ataques en 172.30.10.11.
- **Horas en UTC.** La Kali y los logs van en UTC; tu ordenador y el dashboard,
  en tu hora local. Convertir zonas horarias es parte del trabajo en un SOC.
- **Después de un `git pull`**, `./lab.sh up` reconstruye solo lo que haya cambiado
  (la Kali y las víctimas); tarda unos segundos.
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
  de Samir Bousseaden (GPLv3); se descargan bajo demanda, no se incluyen en este repo.
- El resto del código: licencia MIT. Detalles en [NOTICE](NOTICE).

Hecho por **Jonathas Carneiro** · [YouTube](https://www.youtube.com/@DateUnH4ck) · [GitHub](https://github.com/dat3unh4ck)
