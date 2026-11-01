#!/usr/bin/env bash
# =============================================================================
#  soc-lab · gestor del laboratorio (Mac / Linux / WSL)
#  En Windows con PowerShell usa .\lab.ps1 (mismos comandos).
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

COMPOSE="docker compose"
MIN_MEM_GB=6
CERTS_DIR="wazuh/certs"

c_ok()   { printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
c_info() { printf "\033[1;36m➜ %s\033[0m\n" "$*"; }
c_warn() { printf "\033[1;33m⚠ %s\033[0m\n" "$*"; }
c_err()  { printf "\033[1;31m✘ %s\033[0m\n" "$*" >&2; }

env_get() {  # lee una variable de .env (con valor por defecto)
  local key="$1" def="$2" val=""
  [ -f .env ] && val=$(grep -E "^${key}=" .env | tail -1 | cut -d= -f2- || true)
  echo "${val:-$def}"
}

usage() {
  cat <<'EOF'

  soc-lab · Laboratorio SOC del curso "De 0 a Analista SOC N2" (@DateUnH4ck)

  Uso: ./lab.sh <comando>

    setup             Primera instalación: comprueba requisitos, genera
                      certificados, construye imágenes y arranca todo
    up                Arranca el laboratorio
    down              Para el laboratorio (conserva alertas y agentes)
    status            Estado de contenedores y agentes Wazuh
    attacker          Abre una shell en la Kali atacante
    shell <servicio>  Abre una shell en un contenedor (srv-web, srv-ssh...)
    replay [args]     Reproduce ataques de Windows en Wazuh
                      (./lab.sh replay --list  |  ./lab.sh replay dcsync)
    logs [servicio]   Muestra los logs (Ctrl+C para salir)
    reset             Borra TODOS los datos (alertas, agentes) y empieza de cero
    help              Esta ayuda

EOF
}

check_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    c_err "Docker no está instalado. Instala Docker Desktop: https://www.docker.com/products/docker-desktop/"
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    c_err "Docker no está arrancado. Abre Docker Desktop (o 'sudo systemctl start docker') y vuelve a probar."
    exit 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    c_err "Falta Docker Compose v2 ('docker compose'). Actualiza Docker."
    exit 1
  fi
  c_ok "Docker $(docker version --format '{{.Server.Version}}') · $(docker compose version --short) · arquitectura $(docker info --format '{{.Architecture}}')"
}

check_memory() {
  local bytes gb
  bytes=$(docker info --format '{{.MemTotal}}')
  gb=$(( bytes / 1024 / 1024 / 1024 ))
  if [ "$gb" -lt "$MIN_MEM_GB" ]; then
    c_warn "Docker solo tiene ${gb} GB de RAM. Recomendado: 8 GB (mínimo ${MIN_MEM_GB})."
    c_warn "Docker Desktop → Settings → Resources → Memory. Ver docs/requisitos.md"
  else
    c_ok "Memoria disponible para Docker: ${gb} GB"
  fi
}

set_max_map_count() {
  # El indexer (OpenSearch) necesita vm.max_map_count >= 262144.
  # Un contenedor privilegiado lo ajusta en el kernel que usa Docker:
  # funciona igual en Linux, Docker Desktop (Mac) y Docker Desktop (Windows/WSL2).
  docker run --rm --privileged alpine:3.20 sysctl -w vm.max_map_count=262144 >/dev/null
  c_ok "vm.max_map_count = 262144"
}

ensure_env() {
  if [ ! -f .env ]; then
    cp .env.example .env
    c_ok "Creado .env a partir de .env.example"
  fi
}

gen_certs() {
  if [ -f "$CERTS_DIR/root-ca.pem" ]; then
    c_ok "Certificados ya generados ($CERTS_DIR)"
    return
  fi
  c_info "Generando certificados TLS de Wazuh..."
  mkdir -p "$CERTS_DIR"
  $COMPOSE --profile setup run --rm certs
  c_ok "Certificados generados"
}

wait_ready() {
  local port tries=0 max=90
  port=$(env_get DASHBOARD_PORT 443)
  c_info "Esperando a que Wazuh esté listo (la primera vez puede tardar 3-5 min)..."
  until $COMPOSE exec -T wazuh.manager sh -c \
      "curl -sk -o /dev/null -w '%{http_code}' https://wazuh.dashboard:5601/app/login | grep -q 200" \
      >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -ge "$max" ]; then
      c_err "Wazuh no responde tras ${max} intentos. Revisa: ./lab.sh logs wazuh.dashboard"
      exit 1
    fi
    printf "."
    sleep 10
  done
  echo
  local url="https://localhost"
  [ "$port" != "443" ] && url="https://localhost:${port}"
  c_ok "Wazuh listo"
  cat <<EOF

  ┌──────────────────────────────────────────────────────────────┐
    Dashboard:   ${url}
    Usuario:     admin
    Contraseña:  $(env_get INDEXER_PASSWORD SecretPassword)
    (El navegador avisará del certificado autofirmado: acéptalo.)

    Siguiente paso:  ./lab.sh attacker   → ataca srv-ssh y srv-web
                     ./lab.sh replay --list
  └──────────────────────────────────────────────────────────────┘

EOF
}

cmd_setup() {
  c_info "Instalando soc-lab"
  check_docker
  check_memory
  ensure_env
  set_max_map_count
  gen_certs
  c_info "Descargando y construyendo imágenes (la primera vez tarda unos minutos)..."
  $COMPOSE pull --ignore-buildable --quiet
  $COMPOSE build
  $COMPOSE --profile tools build replayer
  $COMPOSE up -d
  wait_ready
  cmd_status
}

cmd_up() {
  check_docker
  ensure_env
  if [ ! -f "$CERTS_DIR/root-ca.pem" ]; then
    c_warn "Primera vez: ejecuto 'setup'"
    cmd_setup
    return
  fi
  set_max_map_count
  $COMPOSE up -d
  wait_ready
}

cmd_status() {
  $COMPOSE ps --format 'table {{.Service}}\t{{.State}}\t{{.Status}}'
  echo
  c_info "Agentes Wazuh:"
  $COMPOSE exec -T wazuh.manager /var/ossec/bin/agent_control -l 2>/dev/null \
    | grep -E "ID:" || c_warn "El manager aún no responde."
}

cmd_reset() {
  c_warn "Esto borra TODAS las alertas, agentes y datos del laboratorio."
  read -r -p "¿Seguro? Escribe 'si' para continuar: " answer
  [ "$answer" = "si" ] || { c_info "Cancelado."; exit 0; }
  $COMPOSE --profile tools down -v
  c_ok "Datos borrados. Arranca de nuevo con ./lab.sh up"
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "$cmd" in
    setup)    cmd_setup ;;
    up|start) cmd_up ;;
    down|stop) $COMPOSE --profile tools down ;;
    status|ps) cmd_status ;;
    attacker|kali) $COMPOSE exec attacker bash ;;
    shell)    $COMPOSE exec "${1:?Indica el servicio, p. ej. srv-ssh}" bash ;;
    replay)   $COMPOSE --profile tools run --rm replayer "$@" ;;
    logs)     $COMPOSE logs -f --tail 100 "$@" ;;
    reset)    cmd_reset ;;
    help|-h|--help) usage ;;
    *) c_err "Comando desconocido: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"
