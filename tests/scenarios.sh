#!/usr/bin/env bash
# =============================================================================
#  Comprueba los escenarios del replayer UNO A UNO.
#  Para cada escenario: lo reproduce, espera a que lleguen sus alertas al
#  indexer y muestra cuántas ha generado y con qué reglas.
#  Falla si algún escenario no genera ninguna alerta (así nos aseguramos de que
#  todo lo que prometemos en el curso se ve en el dashboard).
#
#  Requiere el laboratorio arrancado. Lo usa la CI; también puedes lanzarlo tú:
#    ./tests/scenarios.sh            # todos
#    ./tests/scenarios.sh dcsync     # solo uno
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

PASS=$(grep -E '^INDEXER_PASSWORD=' .env 2>/dev/null | cut -d= -f2- || true)
PASS=${PASS:-SecretPassword}
IDX="https://localhost:9200"
FAILED=()

# Escenarios que dependen de una regla propia del lab (wazuh/manager/local_rules.xml):
# además de generar alertas, tiene que saltar esa regla.
declare -A EXPECT=(
  [dcsync]=100100
  [lsass-mimikatz]=100101
  [run-key]=100102
  [pass-the-hash]=100103
  [scheduled-task]=100104
)

if [ $# -gt 0 ]; then
  SCENARIOS=("$@")
else
  mapfile -t SCENARIOS < <(sed -n 's/^  \([a-z0-9-]*\):$/\1/p' replayer/scenarios.yml)
fi

search() {  # $1 = desde (ISO 8601 UTC)
  curl -sk -u "admin:${PASS}" "${IDX}/wazuh-alerts-*/_search" -H 'Content-Type: application/json' -d '{
    "size": 0,
    "query": {"bool": {"filter": [
      {"query_string": {"query": "rule.groups:windows"}},
      {"range": {"timestamp": {"gte": "'"$1"'"}}}
    ]}},
    "aggs": {"reglas": {"terms": {"field": "rule.id", "size": 20},
             "aggs": {"desc": {"terms": {"field": "rule.description", "size": 1}},
                      "nivel": {"max": {"field": "rule.level"}}}}}
  }'
}

total() { python3 -c 'import sys,json; print(json.load(sys.stdin)["hits"]["total"]["value"])' 2>/dev/null || echo 0; }

summary() {
  python3 <(cat <<'PY'
import sys, json
d = json.load(sys.stdin)
for b in d["aggregations"]["reglas"]["buckets"]:
    desc = b["desc"]["buckets"][0]["key"] if b["desc"]["buckets"] else "?"
    rid, lvl, cnt = b["key"], int(b["nivel"]["value"]), b["doc_count"]
    print("      regla %6s  nivel %2d  x%-3d %s" % (rid, lvl, cnt, desc[:90]))
PY
)
}

printf "\n\033[1;36m== Escenarios del replayer, uno a uno (%s)\033[0m\n" "$(docker info --format '{{.Architecture}}')"
for sc in "${SCENARIOS[@]}"; do
  sleep 5   # que no se mezclen las alertas del escenario anterior
  since=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
  ./lab.sh replay "$sc" >/dev/null 2>&1 || { printf "\033[1;31m  ✘ %-16s el replay ha fallado\033[0m\n" "$sc"; FAILED+=("$sc"); continue; }
  n=0
  for i in $(seq 1 12); do
    sleep 5
    n=$(search "$since" | total)
    [ "$n" -gt 0 ] && break
  done
  sleep 10   # damos tiempo a las alertas rezagadas
  res=$(search "$since")
  n=$(echo "$res" | total)
  want=${EXPECT[$sc]:-}
  if [ -n "$want" ] && ! echo "$res" | grep -q "\"key\":\"$want\""; then
    printf "\033[1;31m  ✘ %-16s %3s alertas, pero no salta la regla %s\033[0m\n" "$sc" "$n" "$want"
    echo "$res" | summary
    FAILED+=("$sc")
  elif [ "$n" -gt 0 ]; then
    printf "\033[1;32m  ✔ %-16s %3s alertas\033[0m\n" "$sc" "$n"
    echo "$res" | summary
  else
    printf "\033[1;31m  ✘ %-16s 0 alertas\033[0m\n" "$sc"
    FAILED+=("$sc")
  fi
done

echo
if [ ${#FAILED[@]} -eq 0 ]; then
  printf "\033[1;32mTODOS los escenarios generan alertas\033[0m\n"
else
  printf "\033[1;31mEscenarios sin alertas: %s\033[0m\n" "${FAILED[*]}"
  exit 1
fi
