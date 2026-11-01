#!/usr/bin/env python3
"""
soc-lab replayer
================

Reproduce en Wazuh eventos REALES de ataques en Windows (ficheros .evtx),
como si los hubiera enviado un agente Windows. Asi puedes practicar la
deteccion de ataques a Active Directory y endpoints Windows sin necesitar
una maquina Windows (y funciona igual en PC x86 y en Mac ARM).

Como funciona:
  1. Descarga los .evtx del escenario (y los guarda en cache).
  2. Convierte cada evento a XML, igual que hace el agente de Windows.
  3. Lo entrega en la cola interna del manager de Wazuh (queue/sockets/queue)
     con el mismo formato que usa el agente para el canal "EventChannel".
  4. Wazuh lo decodifica con sus reglas de Windows/Sysmon y genera alertas.

Uso:
  replay.py --list
  replay.py dcsync
  replay.py dcsync psexec --eps 20
  replay.py --all
"""

import argparse
import json
import os
import re
import socket
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

import yaml
import Evtx.Evtx as evtx

HERE = Path(__file__).resolve().parent
QUEUE_SOCKET = os.environ.get("WAZUH_QUEUE_SOCKET", "/wazuh-queue/sockets/queue")
CACHE_DIR = Path(os.environ.get("REPLAYER_CACHE", "/cache"))
MAX_MSG = 65000  # OS_MAXSTR de Wazuh es 65536; dejamos margen

# El agente de Windows usa este identificador de cola para EventChannel ('f')
WIN_EVT_MQ = "f"
LOCATION = "EventChannel"

SYSTEMTIME_RE = re.compile(
    r'SystemTime="(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}(?:\.\d+)?)\+00:00"'
)


def load_catalog():
    with open(HERE / "scenarios.yml", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def print_list(catalog):
    scenarios = catalog["scenarios"]
    width = max(len(k) for k in scenarios)
    print("\nEscenarios disponibles (./lab.sh replay <escenario>):\n")
    print(f"  {'ESCENARIO'.ljust(width)}  {'ATT&CK':10} {'MODULO':26} DESCRIPCION")
    print(f"  {'-' * width}  {'-' * 10} {'-' * 26} {'-' * 40}")
    for key, sc in scenarios.items():
        print(f"  {key.ljust(width)}  {sc['attack']:10} {sc['module']:26} {sc['title']}")
    src = catalog["source"]
    print(f"\nFuente: https://github.com/{src['repo']} (commit {src['commit'][:7]})\n")


def fetch(catalog, rel_path):
    """Descarga un .evtx del repositorio fuente (con cache local)."""
    src = catalog["source"]
    target = CACHE_DIR / src["commit"][:12] / rel_path
    if target.exists() and target.stat().st_size > 0:
        return target
    target.parent.mkdir(parents=True, exist_ok=True)
    url = "https://raw.githubusercontent.com/{}/{}/{}".format(
        src["repo"], src["commit"], urllib.parse.quote(rel_path)
    )
    print(f"  · descargando {rel_path}")
    tmp = target.with_suffix(".part")
    with urllib.request.urlopen(url, timeout=60) as resp, open(tmp, "wb") as out:
        out.write(resp.read())
    tmp.rename(target)
    return target


TAG_RE = re.compile(r"<[^<>]+>")
ATTR_RE = re.compile(r'="([^"]*)"')


def _single_quote_attrs(tag_match):
    # Windows (EvtRender) escribe los atributos con comillas simples y el
    # decoder de Wazuh lo espera asi: name='valor'
    return ATTR_RE.sub(
        lambda m: "='" + m.group(1).replace("'", "&apos;") + "'", tag_match.group(0)
    )


def to_agent_xml(raw_xml):
    """Deja el XML como lo envia el agente de Windows:
    una sola linea, atributos con comillas simples y fecha ISO 8601."""
    xml = re.sub(r">\s+<", "><", raw_xml.strip())
    xml = xml.replace("\r", " ").replace("\n", " ").replace("\t", " ")
    xml = SYSTEMTIME_RE.sub(lambda m: f'SystemTime="{m.group(1)}T{m.group(2)}Z"', xml)
    return TAG_RE.sub(_single_quote_attrs, xml)


def open_queue():
    if not os.path.exists(QUEUE_SOCKET):
        sys.exit(
            f"\n[!] No encuentro la cola de Wazuh en {QUEUE_SOCKET}.\n"
            "    ¿Está arrancado el laboratorio? Prueba: ./lab.sh status\n"
        )
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    sock.connect(QUEUE_SOCKET)
    return sock


def replay_file(sock, path, eps):
    sent = skipped = 0
    delay = 1.0 / eps if eps > 0 else 0
    with evtx.Evtx(str(path)) as log:
        for record in log.records():
            try:
                xml = to_agent_xml(record.xml())
            except Exception:  # registro corrupto en el .evtx
                skipped += 1
                continue
            payload = json.dumps({"Event": xml}, ensure_ascii=False, separators=(",", ":"))
            msg = f"{WIN_EVT_MQ}:{LOCATION}:{payload}".encode("utf-8")
            if len(msg) > MAX_MSG:
                skipped += 1
                continue
            sock.send(msg)
            sent += 1
            if delay:
                time.sleep(delay)
    return sent, skipped


def main():
    parser = argparse.ArgumentParser(
        description="Reproduce ataques reales de Windows (EVTX) en Wazuh."
    )
    parser.add_argument("scenarios", nargs="*", help="escenarios a reproducir")
    parser.add_argument("--list", action="store_true", help="lista los escenarios")
    parser.add_argument("--all", action="store_true", help="reproduce todos")
    parser.add_argument(
        "--eps", type=float, default=50,
        help="eventos por segundo (por defecto 50; 0 = sin limite)",
    )
    args = parser.parse_args()

    catalog = load_catalog()
    if args.list or (not args.scenarios and not args.all):
        print_list(catalog)
        return

    names = list(catalog["scenarios"]) if args.all else args.scenarios
    unknown = [n for n in names if n not in catalog["scenarios"]]
    if unknown:
        print(f"[!] Escenario desconocido: {', '.join(unknown)}")
        print_list(catalog)
        sys.exit(1)

    sock = open_queue()
    total = 0
    for name in names:
        sc = catalog["scenarios"][name]
        print(f"\n▶ {name} — {sc['title']} ({sc['attack']})")
        for rel in sc["files"]:
            path = fetch(catalog, rel)
            sent, skipped = replay_file(sock, path, args.eps)
            total += sent
            extra = f", {skipped} omitidos" if skipped else ""
            print(f"  ✓ {sent} eventos enviados desde {Path(rel).name}{extra}")
    sock.close()
    print(
        f"\nListo: {total} eventos entregados a Wazuh.\n"
        "Búscalos en el dashboard: Threat Hunting → filtra por "
        "rule.groups: windows  (agente: wazuh.manager)\n"
    )


if __name__ == "__main__":
    main()
