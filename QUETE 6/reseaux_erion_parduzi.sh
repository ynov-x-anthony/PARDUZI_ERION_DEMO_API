#!/usr/bin/env bash
# quete 6 : demo-api + postgres sur deux reseaux separes
#   demo_front : l'api (publiee sur 8080)
#   demo_back  : l'api + la base (la base n'a aucun port publie)
# a lancer depuis la racine du repo : bash "QUETE 6/reseaux_erion_parduzi.sh"
set -e
export MSYS_NO_PATHCONV=1   # sinon git bash sur windows modifie les chemins /docker-entrypoint-initdb.d...

# au cas ou un ancien test traine
docker rm -f demo-api demo-db >/dev/null 2>&1 || true
docker network rm demo_front demo_back >/dev/null 2>&1 || true

echo "== build de l'image demo-api:1.0"
docker build -q -t demo-api:1.0 ./api >/dev/null

echo "== creation des reseaux"
docker network create demo_front
docker network create demo_back

echo "== base sur demo_back uniquement, sans -p"
docker run -d --name demo-db --network demo_back \
  -e POSTGRES_USER=demo -e POSTGRES_PASSWORD=demo -e POSTGRES_DB=demo \
  -v "$(pwd)/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
  postgres:16-alpine >/dev/null
until docker exec demo-db pg_isready -U demo -d demo -h 127.0.0.1 >/dev/null 2>&1; do sleep 1; done

echo "== api sur demo_front + demo_back, publiee sur 8080"
docker run -d --name demo-api --network demo_front -p 8080:3000 -e PGHOST=demo-db demo-api:1.0 >/dev/null
docker network connect demo_back demo-api
sleep 2

echo
echo "== reseaux de chaque conteneur"
for c in demo-db demo-api; do
  echo "$c : $(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' $c)"
done
echo "ports publies demo-db  : [$(docker port demo-db)]"
echo "ports publies demo-api : [$(docker port demo-api | tr '\n' ' ')]"

echo
echo "== adresses IPv4"
for c in demo-db demo-api; do
  echo "-- $c"
  docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} : {{$v.IPAMConfig}} {{$v.IPAddress}}{{"\n"}}{{end}}' $c
done

echo "== demo-api joint demo-db par son nom"
docker exec demo-api getent hosts demo-db

echo
echo "== conteneur tiers sur demo_front seulement -> doit echouer"
if docker run --rm --network demo_front alpine:3.20 nc -zv -w 3 demo-db 5432; then
  echo "PROBLEME : demo-db est joignable depuis demo_front"
else
  echo "echec attendu : demo-db n'est pas joignable depuis demo_front"
fi

echo
echo "== pour comparer : un conteneur tiers sur demo_back y arrive"
docker run --rm --network demo_back alpine:3.20 nc -zv -w 3 demo-db 5432 || true

echo
echo "== curl localhost:8080/products"
curl -s localhost:8080/products; echo

echo
echo "== nettoyage"
docker rm -f demo-api demo-db
docker network rm demo_front demo_back
