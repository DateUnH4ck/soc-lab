# Cambios del laboratorio

Para pasar a la última versión sin perder tus alertas: `./lab.sh update`
(Windows: `.\lab.ps1 update`). Mira tu versión con `./lab.sh version`.

## 1.2.0 · noviembre de 2026

Todo lo que necesita la temporada 1 del curso (episodios E07 a E18).

- **HTTPS en srv-web** (443, certificado autofirmado para `srv-web.hackerlab.local`
  y `www.hackerlab.local`). El log web añade al final `xff=` (X-Forwarded-For),
  `tls=` (versión de TLS) y `sni=` (nombre pedido en el saludo TLS).
- **srv-proxy** (172.30.10.8): proxy de salida de la empresa con Squid y agente
  Wazuh, puerto 3128. Cada petición que sale bien es una alerta de nivel 3
  (`100120`); los errores los cubren las reglas de serie de Wazuh.
- **Replayer con dos fuentes** de muestras: EVTX-ATTACK-SAMPLES y
  EVTX-to-MITRE-Attack (CC0). **14 escenarios nuevos** (25 en total):
  `process-4688`, `unquoted-service`, `task-4698`, `wmi-persistence`,
  `powershell-4104`, `uac-bypass`, `local-account`, `kerbrute`,
  `ntlm-bruteforce`, `kerberoast`, `asrep-roast`, `bloodhound`,
  `dcsync-rights` y `log-cleared`.
- Reglas nuevas: Kerberoasting (`100106`), AS-REP roasting (`100107`), TGT de
  Kerberos 4768 (`100108`) y validación NTLM 4776 (`100109`) como telemetría.
- **srv-ssh**: cron (cronie, log en `/var/log/cron`), `sudo` para el grupo
  `wheel` (mgarcia) y FIM en tiempo real sobre `/etc`, `/var/spool/cron` y
  `/home` (sin mostrar nunca el contenido de `/etc/shadow`).
- **`./lab.sh turno`**: simula unos minutos de actividad en la empresa
  (ataques, cambios legítimos y ruido) para practicar un turno de N1.

## 1.1.0 · noviembre de 2026

Para los episodios de redes del curso (DNS y Wireshark).

- **srv-dns** (172.30.10.53): el DNS interno de la empresa, con dnsmasq y agente
  Wazuh. Zona `hackerlab.local` (registros A, CNAME, MX, TXT y PTR) y el dominio
  del atacante `malo.test`. La Kali y los servidores lo usan como DNS.
- Decoder y reglas de DNS en Wazuh: cada consulta (`100111`) y respuesta
  (`100112`), subdominio muy largo (`100113`) y ráfaga de consultas (`100114`).
- `./lab.sh capture <servicio> [segundos]`: captura el tráfico de un contenedor
  en `captures/*.pcap` para abrirlo con Wireshark.
- La Kali trae `tcpdump`, `ip` y `ss`.
- `./lab.sh update`: actualiza el laboratorio conservando alertas, agentes y
  certificados. `./lab.sh version`: muestra la versión instalada.

## 1.0.0 · 1 de noviembre de 2026

Fase 1: Wazuh 4.14 (indexer, manager y dashboard), srv-web, srv-ssh, la Kali,
el replayer de ataques de Windows con 11 escenarios y las reglas propias
100100–100105. Probado en x86_64, ARM64 y Windows.
