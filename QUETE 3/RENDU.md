# Quête 3 - Dockerfile et sécurité

Code de cette étape : tag `quete-3` (https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/tree/quete-3)

Image : `erionparduzi/demo-api:hardened` sur Docker Hub

## Pour tester

```bash
git clone https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API.git
cd PARDUZI_ERION_DEMO_API
git checkout quete-3
sh "QUETE 3/test.sh"
```

J'ai fait un petit script `test.sh` pour pas avoir à tout retaper à chaque fois : il build l'image, crée le réseau demo_net, lance postgres avec le init.sql, lance l'API en mode durci et affiche les vérifs. À la fin il supprime tout (mettre `KEEP=1` devant pour garder les conteneurs).

## Ce que j'ai changé

Dans `api/Dockerfile` :
- base `node:22.11-alpine` au lieu de `node:22-alpine`
- `COPY --chown=node:node` et `USER node` juste avant le CMD
- un HEALTHCHECK sur /health (avec le fetch de node, comme ça pas besoin d'installer curl)
- `npm cache clean --force` dans le même RUN que npm ci

Dans `api/.dockerignore` j'ai rajouté les fichiers de clés (*.pem, *.key) et les dossiers de tests.

```dockerfile
FROM node:22.11-alpine

WORKDIR /app

# on donne les fichiers à l'utilisateur node avant de passer en USER node
COPY --chown=node:node package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --chown=node:node server.js db.js ./

ENV NODE_ENV=production PORT=3000
EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

USER node

CMD ["node", "server.js"]
```

## La commande docker run

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

## Résultats

```
$ docker run --rm demo-api:hardened id
uid=1000(node) gid=1000(node) groups=1000(node),1000(node)

$ curl -s localhost:8080/health
{"status":"UP"}
$ curl -s localhost:8080/ready
{"status":"READY"}

$ docker exec api sh -c 'touch /app/x 2>&1 || echo "rootfs read-only OK"'
touch: /app/x: Read-only file system
rootfs read-only OK

$ docker inspect -f 'readonly={{.HostConfig.ReadonlyRootfs}} capdrop={{.HostConfig.CapDrop}}' api
readonly=true capdrop=[ALL]
```

Le conteneur passe aussi en `healthy` après le premier healthcheck. /products renvoie bien les 3 produits du init.sql, donc la connexion à la base marche même avec le conteneur en read-only.

Petit souci rencontré : sous Git Bash sur Windows, les chemins comme `/tmp` ou `/docker-entrypoint-initdb.d` étaient transformés en chemins Windows. J'ai mis `MSYS_NO_PATHCONV=1` dans le script pour éviter ça.

## Quiz

1. sans user namespace, root dans le conteneur = root sur l'hôte + capabilities larges
2. juste avant le CMD, après les chown / installs
3. non, port < 1024 : on écoute sur 3000 et on publie avec -p 80:3000
4. oui, visible dans docker history --no-trunc
5. non, il reste dans le layer du COPY
6. retire toutes les capabilities Linux
7. rend le système de fichiers non modifiable sauf /tmp en RAM
8. ça donne le contrôle du démon Docker, donc de l'hôte
9. tag qui change : on sait pas ce qui tourne ni comment revenir en arrière
10. l'escalade de privilèges via les binaires setuid
