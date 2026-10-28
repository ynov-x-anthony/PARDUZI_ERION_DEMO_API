#!/usr/bin/env sh
# quete 9 : api + notifier en local
# a lancer depuis la racine du repo : sh "QUETE 9/test.sh"
set -e
export MSYS_NO_PATHCONV=1

[ -f .env ] || cp .env.example .env
if [ ! -f secrets/db_password.txt ]; then
  mkdir -p secrets
  printf '%s' "$(head -c 18 /dev/urandom | base64 | tr -d '/+=')" > secrets/db_password.txt
fi

docker compose down -v >/dev/null 2>&1 || true

echo "== up"
docker compose up -d --build --wait 2>&1 | grep -E 'Healthy' | sort -u || true
docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'

echo
echo "== reseaux"
for s in api notifier db adminer; do
  c=$(docker compose ps -q $s)
  echo "$s : $(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' $c)"
done

echo
echo "== POST /products"
curl -s -X POST localhost:8080/products -H "Content-Type: application/json" \
  -d '{"name":"Clavier meca","price_cents":5900}'; echo
sleep 1
echo "-- logs notifier"
docker compose logs notifier | tail -5

echo
echo "== l'api trouve notifier par son nom"
docker compose exec -T api getent hosts notifier
echo "-- un conteneur seulement sur front trouve pas notifier :"
docker run --rm --network demo-api_front alpine:3.20 nslookup notifier 2>&1 | tail -2 || true

echo
echo "== on coupe notifier, le POST doit quand meme repondre 201"
docker compose stop notifier
curl -s -w "  [HTTP %{http_code}]" -X POST localhost:8080/products -H "Content-Type: application/json" \
  -d '{"name":"Souris sans notif","price_cents":1500}'; echo
sleep 3
echo "-- logs api (l'erreur est juste loggee)"
docker compose logs api | grep 'notify failed' | tail -1
docker compose start notifier >/dev/null

if [ "$KEEP" != "1" ]; then
  echo
  docker compose down -v >/dev/null 2>&1
  echo "== nettoyage fait"
fi
