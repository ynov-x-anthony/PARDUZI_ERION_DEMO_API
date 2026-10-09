# Quête 4 - Builds multi-étapes et gestion des secrets

Code de cette étape : tag `quete-4` (https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/tree/quete-4)

Image : `erionparduzi/demo-api:multi` sur Docker Hub

## Pour tester

```bash
git clone https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API.git
cd PARDUZI_ERION_DEMO_API
git checkout quete-4
sh "QUETE 4/test.sh"
```

Le script crée un faux .npmrc avec `FAKE-123`, build les deux images (la multi avec `--secret`), compare les tailles, vérifie que le token n'est nulle part et teste /health.

J'ai mis le faux .npmrc dans un dossier temporaire et pas dans `~/.npmrc` comme dans l'énoncé, pour pas risquer d'écraser un vrai fichier. Sur Windows il faut passer un chemin Windows à `--secret`, donc le script utilise `cygpath` quand on est sous Git Bash (du coup pas besoin de WSL).

## Les fichiers

- `api/Dockerfile.naive` : juste là pour la comparaison, c'est pas le Dockerfile de prod
- `api/Dockerfile.multi` : deux étapes, deps puis runtime

```dockerfile
# syntax=docker/dockerfile:1

FROM node:22.11-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
# le .npmrc est monté seulement pendant ce RUN, il finit dans aucun layer
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci --omit=dev

FROM node:22.11-alpine AS runtime
ENV NODE_ENV=production PORT=3000
WORKDIR /app
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node server.js db.js package.json ./
USER node
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "server.js"]
```

J'ai laissé la ligne `--mount=type=secret` au lieu de l'enlever après le test. Si on build sans `--secret`, rien n'est monté et ça marche quand même.

## Comparaison des tailles

| Image | Taille |
|---|---|
| demo-api:naive | 1.65GB |
| demo-api:multi | 228MB |

Ratio d'environ 7,3, donc largement plus que x2.

La multi fait la même taille que la `hardened` de la quête 3 (228MB aussi). C'est logique vu que le Dockerfile de la quête 3 était déjà en alpine avec --omit=dev, comme le dit l'énoncé.

## Le secret

```
$ docker history --no-trunc demo-api:multi | grep -i FAKE-123
(rien)

$ docker run --rm -u root demo-api:multi sh -c 'cat /root/.npmrc 2>&1'
cat: can't open '/root/.npmrc': No such file or directory
```

J'ai dû mettre `-u root` : sans ça, l'image tourne en `node` et on a juste "Permission denied" sur /root, ce qui prouve pas que le fichier est absent. J'ai aussi fait un grep de FAKE-123 dans tout le système de fichiers de l'image, il trouve rien.

## Contenu de l'image finale

```
$ docker run --rm demo-api:multi ls -la /app
-rwxr-xr-x    1 node     node          1326 db.js
drwxr-xr-x   84 node     node          4096 node_modules
-rwxr-xr-x    1 node     node           401 package.json
-rwxr-xr-x    1 node     node          2851 server.js
```

Il n'y a que le code et les dépendances de prod (6 Mo de node_modules), pas de package-lock ni de dev-deps. Dans docker history on voit que les layers du runtime, l'étape deps apparaît pas.

/health répond toujours `{"status":"UP"}` et l'image tourne en uid 1000 (node).

## Quiz

1. séparer l'environnement de build de celui d'exécution
2. uniquement son propre FROM + ce que COPY --from ramène
3. une étape nommée ou une image externe
4. ça n'allège pas l'image, le fichier reste dans le layer d'avant
5. musl au lieu de glibc, les binaires natifs précompilés marchent pas
6. RUN --mount=type=secret + docker build --secret
7. dans docker history --no-trunc
8. il installe exactement ce qu'il y a dans le package-lock.json
9. pas de shell ni de gestionnaire de paquets, debug plus dur
10. un binaire statique (Go, Rust)
