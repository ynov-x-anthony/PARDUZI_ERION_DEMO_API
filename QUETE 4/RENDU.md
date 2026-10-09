# Quête 4 – Builds multi-étapes et gestion des secrets

> Version figée de cette quête : tag [`quete-4`](https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/tree/quete-4)
> Image publiée : [`erionparduzi/demo-api:multi`](https://hub.docker.com/r/erionparduzi/demo-api/tags)

## Comment tester

```bash
git clone https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API.git
cd PARDUZI_ERION_DEMO_API
git checkout quete-4
sh "QUETE 4/test.sh"
```

Le script [`test.sh`](test.sh) :

- crée un **faux** `.npmrc` (`FAKE-123`) dans un dossier temporaire, sans toucher au vrai `~/.npmrc` ;
- construit `:naive` et `:multi` (avec `--secret`) ;
- affiche le comparatif de taille et vérifie que le secret n'a pas fui ;
- teste `/health`.

Il marche sous Linux, macOS, WSL **et Git Bash Windows** (conversion du chemin via `cygpath`).

## Fichiers

- [`api/Dockerfile.naive`](../api/Dockerfile.naive) : **repère de comparaison uniquement**, volontairement lourd (`node:22` complet, `COPY . .`, `npm ci` avec dev-deps). Ce n'est pas le Dockerfile de prod.
- [`api/Dockerfile.multi`](../api/Dockerfile.multi) : multi-étapes `deps` → `runtime`, avec `RUN --mount=type=secret`.
- [`api/Dockerfile`](../api/Dockerfile) : le Dockerfile durci de la quête 3, inchangé.

```dockerfile
# syntax=docker/dockerfile:1

# --- étape deps : installe les dépendances de prod, puis est jetée ----------
FROM node:22.11-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
# Le secret "npmrc" (token d'un registre privé) est monté en RAM le temps de ce
# RUN uniquement : il n'entre dans aucun layer. Sans --secret, rien n'est monté
# et npm utilise le registre public.
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci --omit=dev

# --- étape runtime : uniquement ce qu'il faut pour exécuter -----------------
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

## Taille avant / après

| Image | Dockerfile | Taille |
|---|---|---|
| `demo-api:naive` | `Dockerfile.naive` (node:22, mono-étape) | **1.65GB** |
| `demo-api:multi` | `Dockerfile.multi` (alpine, multi-étapes) | **228MB** |
| `demo-api:hardened` | `Dockerfile` (quête 3) | 228MB |

**Ratio naive / multi ≈ 7.3x**, bien au-delà de l'objectif ×2.

`:multi` fait la même taille que `:hardened`. C'est attendu, comme l'annonce l'énoncé : le Dockerfile durci était déjà en alpine avec `--omit=dev` et une copie minimale. Le multi-étapes apporte surtout la séparation build/runtime et le montage du secret.

## Sortie complète de `test.sh`

```
== Build naive
sha256:0e4a3823096c1c0db0b822cd9ebe7abed25883874f09489dea5fbc6c3c8c3005
== Build multi (avec secret de build)
sha256:ffbd94b335a2a5a30672915eaf7a37155be54db3528c4905606138489c54cfe0
== Tailles
TAG        SIZE
multi      228MB
naive      1.65GB
hardened   228MB
1.0        252MB
ratio naive/multi = 7.3x
== Secret dans docker history ?
aucune ligne (OK)
== Secret dans le système de fichiers ?
cat: can't open '/root/.npmrc': No such file or directory
FAKE-123 introuvable dans tout le systeme de fichiers (OK)
== Contenu de /app (pas de sources superflues)
total 24
drwxr-xr-x    1 root     root          4096 Oct  9 06:46 .
drwxr-xr-x    1 root     root          4096 Oct  9 06:47 ..
-rwxr-xr-x    1 node     node          1326 Oct  9 06:29 db.js
drwxr-xr-x   84 node     node          4096 Oct  9 06:46 node_modules
-rwxr-xr-x    1 node     node           401 Oct  9 06:29 package.json
-rwxr-xr-x    1 node     node          2851 Oct  9 06:31 server.js
== Non-root
uid=1000(node) gid=1000(node) groups=1000(node),1000(node)
== Layers de l'image finale
SIZE      CREATED BY
0B        CMD ["node" "server.js"]
0B        HEALTHCHECK {Test:[CMD-SHELL node -e "fetch(…
0B        EXPOSE [3000/tcp]
0B        USER node
20.5kB    COPY --chown=node:node server.js db.js packa…
6.05MB    COPY --chown=node:node /app/node_modules ./n…
8.19kB    WORKDIR /app
0B        ENV NODE_ENV=production PORT=3000
0B        CMD ["node"]
0B        ENTRYPOINT ["docker-entrypoint.sh"]
20.5kB    COPY docker-entrypoint.sh /usr/local/bin/ # …
== /health
{"status":"UP"}
```

Ce que ça prouve :

- **Le secret ne fuit pas** :
  - `docker history --no-trunc | grep -i FAKE-123` ne renvoie aucune ligne ;
  - `/root/.npmrc` donne `No such file or directory` (vérifié en `-u root`, sinon on aurait seulement un « Permission denied » qui ne prouve rien) ;
  - `FAKE-123` n'apparaît nulle part dans le système de fichiers.
- **L'étape finale est minimale** :
  - `/app` ne contient que `server.js`, `db.js`, `package.json` et `node_modules` (dépendances de prod, 6 Mo) ;
  - pas de `package-lock.json`, de README ni de dev-deps ;
  - l'étape `deps` n'apparaît pas dans `docker history`.
- **L'image fonctionne** : `/health` → `{"status":"UP"}`, en non-root (`uid=1000(node)`).

## Choix

- J'ai **gardé** la ligne `RUN --mount=type=secret` dans `Dockerfile.multi`. Le secret n'est pas `required`, donc le build fonctionne aussi sans `--secret`, et la preuve reste reproductible.
- Le `--secret` pointe vers un faux `.npmrc` temporaire plutôt que vers `$HOME/.npmrc`, pour ne jamais écraser un vrai token.

## Quiz

1. Multi-étapes : **séparer l'environnement de construction (compilos, dev-deps) de l'environnement d'exécution**
2. L'étape finale hérite : **uniquement de son propre FROM + ce que "COPY --from" y amène explicitement**
3. `COPY --from` peut pointer : **une étape nommée OU une image externe (ex. "COPY --from=nginx:1.27 ...")**
4. `RUN rm -rf /cache` plus tard : **n'allège pas l'image : le fichier reste dans le layer où il a été créé (whiteout)**
5. Problème d'alpine : **elle utilise musl (pas glibc) : binaires natifs précompilés KO, node-gyp à recompiler**
6. Token privé au build : **RUN --mount=type=secret,id=... + docker build --secret id=...,src=...**
7. Secret passé en ARG : **dans "docker history --no-trunc" de l'image**
8. `npm ci` : **il installe exactement ce que fixe package-lock.json (reproductible)**
9. distroless : **pas de shell ni de gestionnaire de paquets → debug plus difficile, HEALTHCHECK shell impossible**
10. scratch : **un binaire entièrement statique (Go, Rust) - rien d'autre dans l'image**
