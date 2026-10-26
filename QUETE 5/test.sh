#!/usr/bin/env sh
# quete 5 : les volumes
# a lancer depuis la racine du repo : sh "QUETE 5/test.sh"
set -e
export MSYS_NO_PATHCONV=1

nettoyer() {
  docker rm -f api demo-db web web2 >/dev/null 2>&1 || true
  docker network rm demo_net >/dev/null 2>&1 || true
}
nettoyer
docker volume rm demo_pgdata html_vol >/dev/null 2>&1 || true

attendre_db() {
  until docker exec demo-db pg_isready -U demo -d demo -h 127.0.0.1 >/dev/null 2>&1; do sleep 1; done
}
lancer_db() {
  docker run -d --name demo-db --network demo_net \
    -e POSTGRES_USER=demo -e POSTGRES_PASSWORD=demo -e POSTGRES_DB=demo \
    -v demo_pgdata:/var/lib/postgresql/data \
    -v "$(pwd)/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
    postgres:16-alpine >/dev/null
  attendre_db
}

echo "== 1. sans volume, les donnees partent avec le conteneur"
docker run --name ephemere alpine:3.20 sh -c 'echo coucou > /data.txt && cat /data.txt'
docker rm ephemere >/dev/null
echo "-- nouveau conteneur, meme image :"
docker run --rm alpine:3.20 cat /data.txt 2>&1 || true

echo
echo "== 2. volume nomme pour postgres"
docker build -q -t demo-api:hardened ./api >/dev/null
docker network create demo_net >/dev/null
docker volume create demo_pgdata
lancer_db
docker run -d --name api -p 8080:3000 --network demo_net -e PGHOST=demo-db demo-api:hardened >/dev/null
sleep 2
echo "-- produits au depart (init.sql)"
curl -s localhost:8080/products; echo
echo "-- ajout d'un produit"
curl -s -X POST localhost:8080/products -H 'Content-Type: application/json' -d '{"name":"Produit persistant","price_cents":4200}'; echo

echo
echo "== 3. on supprime le conteneur de la base et on le recree avec le meme volume"
docker rm -f demo-db
lancer_db
echo "-- init.sql n'est pas rejoue (le dossier de donnees n'est plus vide) :"
docker logs demo-db 2>&1 | grep -i "skipping initialization"
echo "-- produits apres recreation"
curl -s localhost:8080/products; echo

echo
echo "== 4. infos sur le volume"
docker volume ls --filter name=demo_pgdata
docker volume inspect -f 'nom={{.Name}} driver={{.Driver}} mountpoint={{.Mountpoint}}' demo_pgdata
echo "-- contenu vu depuis un conteneur jetable"
docker run --rm -v demo_pgdata:/v:ro alpine:3.20 ls /v | head -8
echo "-- suppression impossible tant qu'un conteneur l'utilise"
docker volume rm demo_pgdata 2>&1 || true

echo
echo "== 5. sauvegarde avec pg_dump"
docker exec demo-db pg_dump -U demo -d demo --data-only -t products | grep -A6 '^COPY'

echo
echo "== 6. volume nomme vs bind mount (nginx)"
docker volume create html_vol >/dev/null
docker run -d --name web -p 8081:80 -v html_vol:/usr/share/nginx/html nginx:1.27-alpine >/dev/null
TMPD=$(mktemp -d)
echo '<h1>Montage bind !</h1>' > "$TMPD/index.html"
SITE="$TMPD"; command -v cygpath >/dev/null 2>&1 && SITE=$(cygpath -w "$TMPD")
docker run -d --name web2 -p 8082:80 -v "$SITE":/usr/share/nginx/html nginx:1.27-alpine >/dev/null
sleep 2
echo "-- volume nomme vide -> pre-rempli avec la page de l'image :"
curl -s localhost:8081 | grep -o '<title>.*</title>'
echo "-- bind mount -> le dossier de l'hote cache celui de l'image :"
curl -s localhost:8082
echo "-- tmpfs :"
docker run --rm --tmpfs /tmp:size=64m alpine:3.20 df -h /tmp | tail -1

if [ "$KEEP" != "1" ]; then
  nettoyer
  docker volume rm html_vol >/dev/null
  rm -rf "$TMPD"
  echo
  echo "== nettoyage fait, le volume demo_pgdata est garde (docker volume rm demo_pgdata pour le supprimer)"
fi
