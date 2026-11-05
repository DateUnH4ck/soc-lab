#!/usr/bin/env bash
# =============================================================================
#  Prueba de humo del laboratorio (la usa la CI en x86_64 y en ARM64).
#  Comprueba que: Wazuh arranca, los agentes conectan, y que los ataques del
#  curso generan alertas (fuerza bruta SSH, escaneo web y replay de Windows).
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

step "2. Los agentes srv-web y srv-ssh están activos"
for i in $(seq 1 30); do
  active=$(docker compose exec -T wazuh.manager /var/ossec/bin/agent_control -l \
             | grep -cE "Name: srv-(web|ssh).*Active" || true)
  [ "$active" -ge 2 ] && break
  sleep 10
done
docker compose exec -T wazuh.manager /var/ossec/bin/agent_control -l | grep "ID:" || true
[ "${active:-0}" -ge 2 ] && ok "2 agentes activos" || ko "Solo ${active:-0} agentes activos"

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
  for i in $(seq 1 18); do
    n=$(count "$query")
    [ "$n" -gt 0 ] && break
    sleep 10
  done
  [ "$n" -gt 0 ] && ok "$label: $n alertas" || ko "$label: 0 alertas  (query: $query)"
}
check "SSH: autenticación fallida en srv-ssh" 'agent.name:srv-ssh AND rule.groups:authentication_failed'
check "Web: errores 4xx en srv-web"           'agent.name:srv-web AND rule.groups:web'
check "Windows: eventos reproducidos"          'rule.groups:windows'

echo
if [ "$FAILED" -eq 0 ]; then
  printf "\033[1;32mTODO OK: el laboratorio funciona en %s\033[0m\n" "$(docker info --format '{{.Architecture}}')"
else
  printf "\033[1;31mHay pruebas fallidas\033[0m\n"
  exit 1
fi
