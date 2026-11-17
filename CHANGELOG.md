# Cambios del laboratorio

Para pasar a la última versión sin perder tus alertas: `./lab.sh update`
(Windows: `.\lab.ps1 update`). Mira tu versión con `./lab.sh version`.

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
