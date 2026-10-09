# Quête 2 – Le Dockerfile

## Liens

- Repo GitHub : https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API
  - [`api/Dockerfile`](../api/Dockerfile)
  - [`api/.dockerignore`](../api/.dockerignore)
- Image publiée (Docker Hub) : https://hub.docker.com/r/erionparduzi/demo-api (`erionparduzi/demo-api:1.0`)

## Quiz

1. Lister les images locales : **docker images**
2. Supprimer une image : **docker rmi**
3. Un Dockerfile : **un fichier texte décrivant les étapes de construction d'une image**
4. Copier des fichiers de l'hôte : **COPY**
5. Documenter un port : **EXPOSE**
6. Construire une image : **docker build**
7. Nommer/versionner au build : **avec -t nom:tag**
8. Dockerfile plutôt que commit : **il garde une trace claire et reproductible des étapes de construction**
9. Clé de cache d'un RUN : **le texte exact de la commande (et les layers précédents)**
10. `COPY package.json` avant `COPY . .` : **pour garder l'installation des dépendances en cache quand seul le code change**
11. `.dockerignore` : **exclure des fichiers du contexte de build (rapidité, cache, sécurité)**
12. Mot de passe via ENV/ARG : **non : ARG est visible dans "docker history", ENV dans "docker inspect"**
13. Alpine plus petite : **c'est une distribution minimaliste (busybox + musl), sans les paquets superflus**

## Dockerfile

```dockerfile
# Base Node légère et épinglée (jamais :latest)
FROM node:22-alpine

WORKDIR /app

# 1) Dépendances d'abord : cette couche reste en cache tant que
#    package.json / package-lock.json ne changent pas
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# 2) Le code ensuite : une modif de server.js ne reconstruit que cette couche
COPY server.js db.js ./

ENV PORT=3000
EXPOSE 3000

# Exec form : node est le PID 1 et reçoit bien SIGTERM
CMD ["node", "server.js"]
```

## Test

```
$ docker build -t demo-api:1.0 ./api
$ docker run -d --name api -p 8080:3000 demo-api:1.0
$ curl -s localhost:8080/health
{"status":"UP"}
$ curl -s localhost:8080/
{"ok":true,"app":"demo-api","version":"dev"}
$ curl -s localhost:8080/products
{"error":"db_unavailable","detail":"Connection terminated due to connection timeout"}   (HTTP 503, normal : pas encore de base)
$ docker rm -f api
```

## `docker image ls demo-api`

```
IMAGE          ID             DISK USAGE   CONTENT SIZE   EXTRA
demo-api:1.0   6d1dc36ed56b        252MB         63.2MB        
```

## Preuve du cache (commentaire modifié dans `server.js`, `docker build --progress=plain -t demo-api:1.0 ./api`)

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
