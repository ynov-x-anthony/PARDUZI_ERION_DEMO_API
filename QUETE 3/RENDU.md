# Quête 3 – Dockerfile et sécurité

> Version figée de cette quête : tag [`quete-3`](https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/tree/quete-3)
> Image publiée : [`erionparduzi/demo-api:hardened`](https://hub.docker.com/r/erionparduzi/demo-api/tags)

## Comment tester

```bash
git clone https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API.git
cd PARDUZI_ERION_DEMO_API
git checkout quete-3
sh "QUETE 3/test.sh"          # KEEP=1 sh "QUETE 3/test.sh" pour garder les conteneurs
```

Le script [`test.sh`](test.sh) construit l'image, crée le réseau `demo_net`, lance PostgreSQL (avec `db/init.sql`), lance l'API durcie puis affiche toutes les preuves ci-dessous.

## Ce qui a changé

- [`api/Dockerfile`](../api/Dockerfile) :
  - base épinglée `node:22.11-alpine` ;
  - `COPY --chown=node:node` pour les manifestes et le code, `USER node` juste avant le `CMD` ;
  - `npm cache clean --force` dans le même `RUN` que `npm ci` ;
  - `HEALTHCHECK` sur `/health` (fetch natif de Node, aucun paquet en plus) ;
  - `EXPOSE 3000` (port ≥ 1024).
- [`api/.dockerignore`](../api/.dockerignore) : `.git`, `.env*`, `node_modules`, `*.md`, clés (`*.pem`, `*.key`), tests.

## Dockerfile durci

```dockerfile
# Base épinglée sur une version mineure précise (ni node:22-alpine, ni latest)
FROM node:22.11-alpine

WORKDIR /app

# 1) Dépendances d'abord (couche mise en cache tant que les manifestes ne changent pas).
#    Les fichiers appartiennent à "node" (uid 1000, fourni par l'image) : le chown
#    se fait AVANT de basculer sur USER node.
COPY --chown=node:node package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# 2) Le code ensuite
COPY --chown=node:node server.js db.js ./

ENV NODE_ENV=production PORT=3000
# Port >= 1024 : un utilisateur non-root ne peut pas écouter en dessous
EXPOSE 3000

# Sonde de liveness légère (fetch natif de Node 22, pas de curl à installer)
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Utilisateur non privilégié, juste avant le CMD
USER node

# Exec form : node est le PID 1 et reçoit SIGTERM
CMD ["node", "server.js"]
```

## Commande `docker run` durcie

```bash
docker network create demo_net
docker run -d --name demo-db --network demo_net \
  -e POSTGRES_USER=demo -e POSTGRES_PASSWORD=demo -e POSTGRES_DB=demo \
  -v "$(pwd)/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
  postgres:16-alpine

docker run -d --name api -p 8080:3000 \
  --read-only --tmpfs /tmp:size=16m \
  --cap-drop ALL --security-opt no-new-privileges \
  --pids-limit 200 --memory 256m --cpus 1 \
  --network demo_net -e PGHOST=demo-db \
  demo-api:hardened
```

## Preuves (sortie de `test.sh`)

```
== Build
sha256:b4aa5de19ffaab0473fd1faa61b4137ecb46462a2fb34e3114cde6bbe6626eee
== Non-root
uid=1000(node) gid=1000(node) groups=1000(node),1000(node)
== Réseau + base
== API durcie
== /health
{"status":"UP"}
== /ready
{"status":"READY"}
== /products
[{"id":3,"name":"T-shirt conteneur","price_cents":1990,"created_at":"2026-10-09T06:39:31.204Z"},{"id":2,"name":"Mug Docker","price_cents":990,"created_at":"2026-10-09T06:39:31.204Z"},{"id":1,"name":"Sticker Demo","price_cents":150,"created_at":"2026-10-09T06:39:31.204Z"}]
== Écriture sur le rootfs
touch: /app/x: Read-only file system
rootfs read-only OK
== Inspect
readonly=true capdrop=[ALL] secopt=[no-new-privileges] pids=200 mem=268435456 user=node
== Healthcheck (attente du 1er passage)
health=healthy
== Nettoyé (KEEP=1 pour garder les conteneurs)
```

- `id` → `uid=1000(node)` : **non-root**
- `touch /app/x` → `Read-only file system` : **rootfs en lecture seule**
- `docker inspect` → **`readonly=true capdrop=[ALL]`**, plus `no-new-privileges`, `pids=200`, `mem=256 Mo`, `user=node`
- `health=healthy` : le `HEALTHCHECK` fonctionne

## Quiz

1. Root dans le conteneur : **sans user namespace, root dans le conteneur = root sur l'hôte (évasion, bind mount) + capabilities larges**
2. Où placer `USER app` : **juste avant le CMD, après avoir fait les chown/installations nécessaires en root**
3. Non-root sur le port 80 : **non (port < 1024) : on écoute sur 3000/8080 et on publie avec -p 80:3000**
4. Secret en ARG : **il est visible dans "docker history --no-trunc" → compromis**
5. `COPY creds.json` puis `RUN rm` : **non : il reste dans le layer du COPY (récupérable)**
6. `--cap-drop ALL` : **retire toutes les capabilities Linux du conteneur (on n'en rajoute que le strict nécessaire)**
7. `--read-only` (+ `--tmpfs /tmp`) : **rendre le système de fichiers du conteneur non modifiable, sauf /tmp en RAM**
8. Monter `docker.sock` : **lui donner le contrôle du démon Docker, donc de l'hôte : à réserver aux outils de confiance**
9. Bannir `:latest` : **tag mutable : on ne sait pas ce qui tourne ni comment revenir en arrière**
10. `no-new-privileges` : **l'escalade de privilèges via des binaires setuid dans le conteneur**
