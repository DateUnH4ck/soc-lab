# replayer: inyecta en Wazuh eventos reales de Windows (EVTX) como si llegaran
# de un agente Windows. Multi-arquitectura (python:3.12-slim).
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY replay.py scenarios.yml ./

ENTRYPOINT ["python", "/app/replay.py"]
CMD ["--list"]
