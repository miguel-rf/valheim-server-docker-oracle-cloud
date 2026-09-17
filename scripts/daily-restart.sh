#!/usr/bin/env bash
# ==============================================================================
# daily-restart.sh - Reinicio preventivo diario para Valheim Dedicated Server
# ==============================================================================
set -euo pipefail

CONTAINER_NAME="valheim-server-arm64"
LOG_FILE="/home/ubuntu/valheim-server/valheim-restart.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $*" | tee -a "$LOG_FILE"
}

log "=== Iniciando mantenimiento y reinicio preventivo diario ==="

# 1. Verificar si el contenedor está en ejecución
if ! docker ps --format '{{.Names}}' | grep -wq "$CONTAINER_NAME"; then
    log "El contenedor $CONTAINER_NAME no está corriendo. Iniciándolo..."
    docker start "$CONTAINER_NAME"
    exit 0
fi

# 2. Forzar guardado y copia de seguridad (backup zip) antes de reiniciar
log "Forzando backup de seguridad previo al reinicio..."
docker exec "$CONTAINER_NAME" bash -c '[ -f /var/run/valheim/valheim-backup.pid ] && kill -HUP $(cat /var/run/valheim/valheim-backup.pid)' || true
sleep 5

# 3. Limpiar volcados temporales o archivos residuales en /tmp
log "Limpiando archivos temporales y volcados en /tmp..."
docker exec "$CONTAINER_NAME" rm -f /tmp/core* /tmp/dumps/* 2>/dev/null || true

# 4. Reinicio ordenado del contenedor (dando hasta 60s para shutdown limpio de Unity)
log "Reiniciando contenedor $CONTAINER_NAME (timeout 60s)..."
docker restart -t 60 "$CONTAINER_NAME"

# 5. Esperar a que el servidor inicialice
sleep 15
STATUS=$(docker inspect --format '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
log "Estado tras el reinicio: $STATUS"

# 6. Extraer el nuevo join code para registro en log
sleep 10
JOIN_CODE=$(docker logs --tail 60 "$CONTAINER_NAME" 2>/dev/null | grep -o 'join code [0-9]\+' | tail -1 | awk '{print $3}' || echo "N/A")
log "Servidor listo. Join Code: ${JOIN_CODE}"
log "=== Mantenimiento preventivo finalizado con éxito ==="
