# Quête 2 - Le Dockerfile

Code de cette étape : tag `quete-2` (https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/tree/quete-2)

Image : https://hub.docker.com/r/erionparduzi/demo-api (tag `1.0`)

Fichiers : `api/Dockerfile` et `api/.dockerignore`

## Pour tester

```bash
git clone https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API.git
cd PARDUZI_ERION_DEMO_API
git checkout quete-2

docker build -t demo-api:1.0 ./api
docker run -d --name api -p 8080:3000 demo-api:1.0
curl -s localhost:8080/health
curl -s localhost:8080/
docker rm -f api
```

Ou directement avec l'image de Docker Hub : `docker run -d --name api -p 8080:3000 erionparduzi/demo-api:1.0`

## Le Dockerfile

```dockerfile
FROM node:22-alpine

WORKDIR /app

# les dépendances d'abord pour garder le npm ci en cache
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY server.js db.js ./

ENV PORT=3000
EXPOSE 3000

CMD ["node", "server.js"]
```

## Résultats

```
$ curl -s localhost:8080/health
{"status":"UP"}
$ curl -s localhost:8080/
{"ok":true,"app":"demo-api","version":"dev"}
$ curl -s localhost:8080/products
{"error":"db_unavailable","detail":"Connection terminated due to connection timeout"}
```

/products renvoie une 503 vu qu'il n'y a pas encore de base, c'est normal.

docker image ls demo-api :

```
IMAGE          ID             DISK USAGE   CONTENT SIZE   EXTRA
demo-api:1.0   6d1dc36ed56b        252MB         63.2MB
```

Test du cache : j'ai changé un commentaire dans server.js puis relancé `docker build --progress=plain -t demo-api:1.0 ./api`. Le npm ci reste en CACHED, il n'y a que la copie du code qui est refaite :

```
#5 [1/5] FROM docker.io/library/node:22-alpine@sha256:0a7108bf6c7bf5de370ffb1a3ed6be93d405b43ff159f681a8d18c0e2bc2e402
#6 [2/5] WORKDIR /app
#6 CACHED
#7 [3/5] COPY package.json package-lock.json ./
#7 CACHED
#8 [4/5] RUN npm ci --omit=dev
#8 CACHED
#9 [5/5] COPY server.js db.js ./
#9 DONE 0.1s
```

## Quiz

1. docker images
2. docker rmi
3. un fichier texte qui décrit les étapes de construction d'une image
4. COPY
5. EXPOSE
6. docker build
7. -t nom:tag
8. il garde une trace claire et reproductible des étapes
9. le texte exact de la commande (et les layers d'avant)
10. pour garder l'install des dépendances en cache quand seul le code change
11. exclure des fichiers du contexte de build
12. non, ARG se voit dans docker history et ENV dans docker inspect
13. c'est une distrib minimaliste (busybox + musl)
