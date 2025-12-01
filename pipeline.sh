#!/usr/bin/env bash
set -euo pipefail

APP_NAME="kubefoods-backend"
CONTAINER_NAME="backend"

# Usar el Docker de minikube para que el cluster vea la imagen
eval "$(minikube docker-env)"

TAG="${1:-v1}"
IMAGE="${APP_NAME}:${TAG}"

echo "=== [BUILD] Construyendo imagen ${IMAGE} ==="
docker build -t "${IMAGE}" .

echo "=== [DEPLOY] Actualizando deployment con nueva imagen ==="
kubectl set image deployment/${APP_NAME} ${CONTAINER_NAME}=${IMAGE}

echo "=== [DEPLOY] Esperando al rollout ==="
if ! kubectl rollout status deployment/${APP_NAME} --timeout=60s; then
  echo "❌ Rollout fallido, haciendo rollback..."
  kubectl rollout undo deployment/${APP_NAME}
  exit 1
fi

echo "=== [VALIDATE] Health check dentro del cluster ==="

# Limpia si quedó algún pod viejo
kubectl delete pod curl-test --ignore-not-found=true >/dev/null 2>&1 || true

# Crea un pod temporal que ejecuta curl contra el servicio
kubectl run curl-test \
  --restart=Never \
  --image=curlimages/curl \
  --command -- sh -c "curl -s -o /dev/null -w \"%{http_code}\" http://kubefoods-service:80" || true

# Espera un poco a que el pod termine
sleep 5

# Lee el código HTTP de los logs del pod
STATUS_CODE=$(kubectl logs curl-test 2>/dev/null | tail -n1 || echo "")

# Borra el pod de test
kubectl delete pod curl-test --ignore-not-found=true >/dev/null 2>&1 || true

echo "Código HTTP devuelto: ${STATUS_CODE}"

if [ "${STATUS_CODE}" != "200" ]; then
  echo "❌ Health check fallido, haciendo rollback..."
  kubectl rollout undo deployment/${APP_NAME}
  exit 1
fi

echo "✅ Despliegue correcto y health check OK."