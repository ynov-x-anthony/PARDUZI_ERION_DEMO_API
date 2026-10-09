#!/usr/bin/env sh
# quete 3 : build + lancement durci + verifs
# a lancer depuis la racine du repo : sh "QUETE 3/test.sh"
# MSYS_NO_PATHCONV pour que git bash sur windows touche pas aux chemins /tmp, /app...
set -e
export MSYS_NO_PATHCONV=1

# on nettoie si un ancien test traine
docker rm -f api demo-db >/dev/null 2>&1 || true
docker network rm demo_net >/dev/null 2>&1 || true

echo "== Build"
docker build -q -t demo-api:hardened ./api

echo "== Non-root"
docker run --rm demo-api:hardened id

echo "== Réseau + base"
docker network create demo_net >/dev/null
docker run -d --name demo-db --network demo_net \
  -e POSTGRES_USER=demo -e POSTGRES_PASSWORD=demo -e POSTGRES_DB=demo \
  -v "$(pwd)/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
  postgres:16-alpine >/dev/null
until docker exec demo-db pg_isready -U demo -d demo -h 127.0.0.1 >/dev/null 2>&1; do sleep 1; done

echo "== API durcie"
docker run -d --name api -p 8080:3000 \
  --read-only --tmpfs /tmp:size=16m \
  --cap-drop ALL --security-opt no-new-privileges \
  --pids-limit 200 --memory 256m --cpus 1 \
  --network demo_net -e PGHOST=demo-db \
  demo-api:hardened >/dev/null
sleep 3

echo "== /health";   curl -s localhost:8080/health;   echo
echo "== /ready";    curl -s localhost:8080/ready;    echo
echo "== /products"; curl -s localhost:8080/products; echo

echo "== Écriture sur le rootfs"
docker exec api sh -c 'touch /app/x 2>&1 || echo "rootfs read-only OK"'

echo "== Inspect"
docker inspect -f 'readonly={{.HostConfig.ReadonlyRootfs}} capdrop={{.HostConfig.CapDrop}} secopt={{.HostConfig.SecurityOpt}} pids={{.HostConfig.PidsLimit}} mem={{.HostConfig.Memory}} user={{.Config.User}}' api

echo "== Healthcheck (attente du 1er passage)"
sleep 15
docker inspect -f 'health={{.State.Health.Status}}' api

if [ "$KEEP" != "1" ]; then
  docker rm -f api demo-db >/dev/null
  docker network rm demo_net >/dev/null
  echo "== nettoyage fait (KEEP=1 pour garder les conteneurs)"
fi
