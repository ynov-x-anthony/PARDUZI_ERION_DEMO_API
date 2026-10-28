#!/usr/bin/env sh
# quete 7 : la stack en compose
# a lancer depuis la racine du repo : sh "QUETE 7/test.sh"
set -e
export MSYS_NO_PATHCONV=1

# .env et secret pas commites -> on les cree s'ils existent pas
[ -f .env ] || cp .env.example .env
if [ ! -f secrets/db_password.txt ]; then
  mkdir -p secrets
  printf '%s' "$(head -c 18 /dev/urandom | base64 | tr -d '/+=')" > secrets/db_password.txt
  echo "secret genere dans secrets/db_password.txt"
fi

docker compose down -v >/dev/null 2>&1 || true

echo "== docker compose config (extrait)"
docker compose config | sed -n '/^  api:/,/^  db:/p' | grep -E 'PG|published|condition|secrets|- source' || true

echo
echo "== up"
docker compose up -d --build --wait 2>&1 | grep -E 'Healthy|Started' | sort -u || true
docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'

echo
echo "== /products"
curl -s localhost:8080/products; echo
echo "== /ready"
curl -s localhost:8080/ready; echo
echo "== adminer"
curl -sI localhost:8081 | head -1

echo
echo "== le mot de passe n'est pas en clair dans les variables"
echo "-- variables PG de l'api :"
docker compose exec -T api printenv | grep '^PG' | sort
echo "-- variables POSTGRES de la db :"
docker compose exec -T db printenv | grep '^POSTGRES' | sort
echo "-- le secret est un fichier monte :"
docker compose exec -T db ls -l /run/secrets/

echo
echo "== la db n'est pas publiee"
echo "ports db : $(docker compose ps db --format '{{.Ports}}')  (pas de 0.0.0.0:xxxx, donc rien de publie sur l'hote)"

echo
echo "== persistance : ajout d'un produit, down, up"
curl -s -X POST localhost:8080/products -H 'Content-Type: application/json' -d '{"name":"Ajout compose","price_cents":500}'; echo
docker compose down 2>&1 | grep -E 'Removed' || true
docker volume ls --filter name=demo-api_pgdata
docker compose up -d --wait >/dev/null 2>&1
curl -s localhost:8080/products; echo

if [ "$KEEP" != "1" ]; then
  echo
  echo "== down -v (supprime aussi le volume)"
  docker compose down -v 2>&1 | grep -E 'Volume|Network' || true
fi
