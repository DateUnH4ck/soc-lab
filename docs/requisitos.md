# Requisitos y memoria

| | Mínimo | Recomendado |
|---|---|---|
| RAM asignada a Docker | 6 GB | 8 GB o más |
| CPU | 2 núcleos | 4 núcleos |
| Disco libre | 15 GB | 25 GB |
| Arquitectura | x86_64 o ARM64 | — |

Consumo aproximado de la fase 1: indexer ~1,5 GB, manager ~1 GB, dashboard
~0,5 GB y el resto de contenedores menos de 0,5 GB entre todos.

## Cómo dar más memoria a Docker

**Mac (Docker Desktop):** Settings → Resources → Memory → 8 GB → *Apply & restart*.

**Windows (Docker Desktop con WSL2):** Docker usa por defecto la mitad de la RAM
del PC. Si tienes 16 GB no hace falta tocar nada. Para cambiarlo, crea o edita
`%UserProfile%\.wslconfig`:

```ini
[wsl2]
memory=8GB
```

y reinicia WSL con `wsl --shutdown` (en PowerShell) y luego Docker Desktop.

**Linux:** Docker usa directamente la RAM del sistema.

## ¿Y si mi ordenador tiene poca RAM?

Baja el heap del indexer en `.env`:

```ini
INDEXER_HEAP=512m
```

Irá más lento, pero funciona para seguir el curso.
