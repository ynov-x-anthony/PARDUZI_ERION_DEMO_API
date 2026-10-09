#!/usr/bin/env sh
# quete 4 : comparaison naive / multi + verif que le secret fuit pas
# a lancer depuis la racine du repo : sh "QUETE 4/test.sh"
set -e
export MSYS_NO_PATHCONV=1

# faux .npmrc dans un dossier temporaire pour pas toucher au vrai ~/.npmrc
TMPD=$(mktemp -d)
echo "//registry.npmjs.org/:_authToken=FAKE-123" > "$TMPD/.npmrc"
SECRET_SRC="$TMPD/.npmrc"
# sous git bash, docker veut un chemin windows
command -v cygpath >/dev/null 2>&1 && SECRET_SRC=$(cygpath -w "$SECRET_SRC")

echo "== Build naive"
docker build -q -f api/Dockerfile.naive -t demo-api:naive ./api
echo "== Build multi (avec secret de build)"
docker build -q -f api/Dockerfile.multi --secret id=npmrc,src="$SECRET_SRC" -t demo-api:multi ./api
rm -rf "$TMPD"

echo "== Tailles"
docker image ls demo-api --format 'table {{.Tag}}\t{{.Size}}'
naive=$(docker image inspect -f '{{.Size}}' demo-api:naive)
multi=$(docker image inspect -f '{{.Size}}' demo-api:multi)
echo "ratio naive/multi = $(awk "BEGIN{printf \"%.1f\", $naive/$multi}")x"

echo "== Secret dans docker history ?"
docker history --no-trunc demo-api:multi | grep -i FAKE-123 || echo "aucune ligne "
echo "== Secret dans le système de fichiers ?"
# en root sinon on a juste permission denied sur /root
docker run --rm -u root demo-api:multi sh -c 'cat /root/.npmrc 2>&1; grep -rsl FAKE-123 /app /root /home /tmp /etc /usr /var || echo "FAKE-123 introuvable dans tout le systeme de fichiers "'

echo "== Contenu de /app (pas de sources superflues)"
docker run --rm demo-api:multi ls -la /app
echo "== Non-root"
docker run --rm demo-api:multi id

echo "== Layers de l'image finale"
docker history demo-api:multi --format 'table {{.Size}}\t{{.CreatedBy}}' | cut -c1-110 | head -12

echo "== /health"
docker rm -f api-multi >/dev/null 2>&1 || true
docker run -d --rm --name api-multi -p 8080:3000 demo-api:multi >/dev/null
sleep 2
curl -s localhost:8080/health; echo
docker rm -f api-multi >/dev/null
