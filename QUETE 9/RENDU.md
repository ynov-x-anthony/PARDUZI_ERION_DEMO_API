# Quête 9 - Microservices et déploiement continu

Code de cette étape : tag `quete-9` (https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/tree/quete-9)

Run GitHub Actions vert (tag `v1.5.0`) : https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/actions/runs/40689779485
- `image (api, Dockerfile.multi)` ✅
- `image (notifier, Dockerfile)` ✅
- `deploy` ✅

Images publiées sur GHCR (page des packages : https://github.com/orgs/ynov-x-anthony/packages?repo_name=PARDUZI_ERION_DEMO_API) :
- `ghcr.io/ynov-x-anthony/parduzi_erion_demo_api/api:v1.5.0`
- `ghcr.io/ynov-x-anthony/parduzi_erion_demo_api/notifier:v1.5.0`

(GHCR veut des noms en minuscules, d'où `parduzi_erion_demo_api`)

## Le service notifier

Nouveau dossier [`notifier/`](../notifier) avec son propre `package.json`, son `package-lock.json`, son `server.js` et son `Dockerfile` :
- `GET /health`
- `POST /notify` qui logge ce qu'il reçoit et répond 202

Le Dockerfile reprend le principe de `api/Dockerfile.multi` (2 étapes, base `node:22.23.4-alpine3.24` épinglée, `apk upgrade`, npm retiré, `USER node`, `HEALTHCHECK`) mais avec ses propres dépendances.

Dans [`api/server.js`](../api/server.js), après un `POST /products` réussi, l'api appelle `http://notifier:4000/notify`. L'appel est en best-effort :
- on répond 201 au client d'abord, l'appel à notifier se fait après sans `await`
- s'il plante (notifier arrêté, timeout de 2s) l'erreur est juste loggée

## compose.yml

- deux réseaux `front` et `back`
- `api` : front + back
- `notifier` : **back uniquement, pas de `ports:`**
- `db` : back uniquement
- `adminer` : front (pour être publié) + back (pour joindre la base)
- `api` et `notifier` ont un `build:` (pour le local) et un `image: ghcr.io/...:${IMAGE_TAG:-dev}` (pour le déploiement)

En local `docker compose up -d --build` construit les images. Au déploiement on fait `IMAGE_TAG=v1.5.0 docker compose pull` puis `up -d --no-build`, donc on lance exactement les images construites et scannées par la CI.

## Test en local

```bash
git checkout quete-9
sh "QUETE 9/test.sh"
```

```
== up
 Container demo-api-adminer-1 Healthy 
 Container demo-api-api-1 Healthy 
 Container demo-api-db-1 Healthy 
 Container demo-api-notifier-1 Healthy 
SERVICE    STATUS                    PORTS
adminer    Up 12 seconds             0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp
api        Up 6 seconds (healthy)    0.0.0.0:8080->3000/tcp, [::]:8080->3000/tcp
db         Up 12 seconds (healthy)   5432/tcp
notifier   Up 12 seconds (healthy)   4000/tcp

== reseaux
api : demo-api_back demo-api_front 
notifier : demo-api_back 
db : demo-api_back 
adminer : demo-api_back demo-api_front 

== POST /products
{"id":4,"name":"Clavier meca","price_cents":5900,"created_at":"2026-10-28T12:39:16.618Z"}
-- logs notifier
notifier-1  | [notifier] demarre sur le port 4000
notifier-1  | [notifier] nouveau produit : {"id":4,"name":"Clavier meca","price_cents":5900}

== l'api trouve notifier par son nom
172.20.0.2        notifier  notifier
-- depuis adminer (front + back) ca resout aussi, mais un conteneur que sur front non :
*** Can't find notifier: No answer


== on coupe notifier, le POST doit quand meme repondre 201
 Container demo-api-notifier-1 Stopping 
 Container demo-api-notifier-1 Stopped 
{"id":5,"name":"Souris sans notif","price_cents":1500,"created_at":"2026-10-28T12:39:28.470Z"}  [HTTP 201]
-- logs api (l'erreur est juste loggee)
api-1  | {"level":"warn","msg":"notify failed","err":"The operation was aborted due to timeout"}
 Container demo-api-notifier-1 Starting 
 Container demo-api-notifier-1 Started 

== nettoyage fait
```

Ce qu'on voit :
- après le POST "Clavier meca", notifier logge `nouveau produit : {"id":4,"name":"Clavier meca","price_cents":5900}`
- l'api trouve `notifier` par son nom, un conteneur branché que sur `front` le trouve pas
- avec notifier arrêté (`docker compose stop notifier`), le POST répond quand même **201**, et l'api logge juste `notify failed`

## La CI / CD

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) :

**Job `image`** en matrix (`api` avec `Dockerfile.multi`, `notifier` avec `Dockerfile`) :
1. build de l'image
2. scan Trivy HIGH/CRITICAL `--ignore-unfixed`, bloquant (`exit-code 1`) sur les tags `v*`, juste informatif sur main
3. sur les tags `v*` : login GHCR et push de `ghcr.io/<repo>/<service>:<tag>`. Je pousse l'image déjà scannée (`docker tag` + `docker push`) au lieu de la rebuild

**Job `deploy`** : `needs: image`, seulement sur les tags `v*`.
- si les secrets `DEPLOY_HOST` / `DEPLOY_USER` / `DEPLOY_SSH_KEY` existent : connexion SSH au serveur (`appleboy/ssh-action`) et `docker compose pull && docker compose up -d` dans `/opt/demo-api`
- **sinon (mon cas, j'ai pas de VM) : déploiement simulé sur le runner GitHub**, comme proposé dans les conseils de la quête. Le job fait les mêmes commandes qu'un serveur : checkout du tag, login GHCR, création du `.env` et du secret, `docker compose pull`, `docker compose up -d --no-build --wait`, puis il vérifie que la stack répond et que notifier reçoit bien la notification (le job échoue sinon)

Logs du job `deploy` du run v1.5.0 :

```
CONTAINER             REPOSITORY                                               TAG                 PLATFORM            IMAGE ID            SIZE                CREATED
demo-api-adminer-1    adminer                                                  4                   linux/amd64         f6939b5b4413        119MB               292 years ago
demo-api-api-1        ghcr.io/ynov-x-anthony/parduzi_erion_demo_api/api        v1.5.0              linux/amd64         d7c03d62e042        171MB               292 years ago
demo-api-db-1         postgres                                                 16-alpine           linux/amd64         6a2e324ebe59        294MB               292 years ago
demo-api-notifier-1   ghcr.io/ynov-x-anthony/parduzi_erion_demo_api/notifier   v1.5.0              linux/amd64         cf0d2c3d9107        171MB               292 years ago
NAME                  IMAGE                                                           COMMAND                  SERVICE    CREATED          STATUS                    PORTS
demo-api-adminer-1    adminer:4                                                       "entrypoint.sh docke…"   adminer    12 seconds ago   Up 11 seconds             0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp
demo-api-api-1        ghcr.io/ynov-x-anthony/parduzi_erion_demo_api/api:v1.5.0        "docker-entrypoint.s…"   api        12 seconds ago   Up 5 seconds (healthy)    0.0.0.0:8080->3000/tcp, [::]:8080->3000/tcp
demo-api-db-1         postgres:16-alpine                                              "docker-entrypoint.s…"   db         12 seconds ago   Up 11 seconds (healthy)   5432/tcp
demo-api-notifier-1   ghcr.io/ynov-x-anthony/parduzi_erion_demo_api/notifier:v1.5.0   "docker-entrypoint.s…"   notifier   12 seconds ago   Up 11 seconds (healthy)   4000/tcp
{"status":"UP"}
{"id":4,"name":"Produit deploye","price_cents":100,"created_at":"2026-10-28T12:42:07.549Z"}
notifier-1  | [notifier] demarre sur le port 4000
notifier-1  | [notifier] nouveau produit : {"id":4,"name":"Produit deploye","price_cents":100}
notifier a bien recu la notification
```

On voit que les conteneurs `api` et `notifier` tournent avec les images `v1.5.0` récupérées sur GHCR (pas buildées sur place), que tout est `healthy`, et que notifier a reçu "Produit deploye".

## Limites

Tout tourne sur un seul hôte. `docker compose up -d --scale notifier=3` lancerait 3 notifier sur la même machine mais sans vraie répartition de charge ni redémarrage sur une autre machine si elle tombe. Pour ça il faudrait un orchestrateur multi-hôte comme Docker Swarm (`docker stack deploy` réutilise le compose) ou Kubernetes.

## Quiz

1. chaque service métier a son propre build, sa propre image et son propre cycle de déploiement
2. rien en dehors du réseau interne a besoin de l'appeler, comme la base
3. par son nom de service, résolu par le DNS du réseau Compose
4. une panne de notifier doit pas empêcher la création d'un produit
5. builder, scanner et publier chaque image indépendamment sans dupliquer le job
6. se connecter au serveur et lancer docker compose pull && up -d avec les nouvelles images
7. pour déployer exactement l'image buildée et scannée en CI
8. lance 3 conteneurs notifier sur le même hôte, sans répartir le trafic automatiquement
9. quand il faut répartir les services sur plusieurs machines et gérer leur résilience
