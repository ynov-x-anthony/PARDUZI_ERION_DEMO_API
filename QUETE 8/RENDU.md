# Quête 8 - Analyse de vulnérabilités avec Trivy

Code de cette étape : tag `quete-8` (https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/tree/quete-8)

Fichiers :
- [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) : la CI avec le scan Trivy
- [`api/Dockerfile.multi`](../api/Dockerfile.multi) : l'image scannée
- [`scan-avant.txt`](scan-avant.txt) et [`scan-apres.txt`](scan-apres.txt) : les deux scans complets
- [`.trivyignore`](../.trivyignore) : vide, il reste rien à justifier

J'ai pas installé Trivy, j'ai utilisé l'image docker `aquasec/trivy` (version 0.76.1) :

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest \
  image --severity HIGH,CRITICAL demo-api:multi
```

(sous Git Bash il faut `MSYS_NO_PATHCONV=1` devant, sinon le chemin du docker.sock est modifié)

## Scan avant

```
demo-api:multi (alpine 3.20.3)
Total: 21 (HIGH: 19, CRITICAL: 2)

Node.js (node-pkg)
Total: 34 (HIGH: 31, CRITICAL: 3)
```

55 CVE HIGH/CRITICAL en tout. En regardant le détail :
- côté OS : les paquets de alpine 3.20.3 (openssl, busybox, musl...), la base `node:22.11-alpine` est vieille
- côté node, il y avait 2 libs de mon appli : `body-parser` 1.20.8 et `proxy-addr` 2.0.7 (CRITICAL), qui viennent d'express
- tout le reste (`tar`, `glob`, `cross-spawn`, `minimatch`, `sigstore`...) c'était le **npm** livré avec l'image node, dans `/usr/local/lib/node_modules/npm`

## Ce que j'ai corrigé

1. **Base** : `node:22.11-alpine` → `node:22.23.4-alpine3.24` (alpine 3.24) + `RUN apk upgrade --no-cache`
2. **Dépendances** : `npm audit fix --package-lock-only --omit=dev` dans `api/` → body-parser 1.20.9, proxy-addr 2.0.8, qs 6.15.4 / 6.16.2 (le package-lock.json est commité)
3. **npm retiré de l'image finale** : il sert à rien au runtime (on lance `node server.js`) et c'était lui qui ramenait la plupart des CVE node. Il est toujours dans l'étape `deps` pour faire le `npm ci`, mais cette étape finit pas dans l'image.

```dockerfile
FROM node:22.23.4-alpine3.24 AS runtime
ENV NODE_ENV=production PORT=3000
RUN apk upgrade --no-cache \
 && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
```

J'ai aussi mis la même base dans `api/Dockerfile` (celui utilisé par le compose) et vérifié que la stack de la quête 7 marche toujours.

## Scan après

```bash
trivy image --severity HIGH,CRITICAL --ignore-unfixed demo-api:multi
```

```
│ demo-api:multi (alpine 3.24.3)  │  alpine  │  0  │
│ app/node_modules/.../package.json │ node-pkg │  0  │   (x 86 paquets)
```

**0 CVE HIGH/CRITICAL**, et c'est pareil sans `--ignore-unfixed`. Le `.trivyignore` reste vide.

Il reste 2 CVE "moderate" sur `qs` d'après `npm audit` mais c'est hors du périmètre HIGH/CRITICAL.

## La CI

```yaml
name: CI

on:
  push:
    branches: [main]
    tags: ["v*"]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  build-scan:
    runs-on: ubuntu-latest
    steps:
      # actions epinglees par SHA (un tag peut etre deplace, un SHA non)
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: Setup Buildx
        uses: docker/setup-buildx-action@f87e5991a6d7451dcb8d9637bfbc97413f497069 # v4.4.1

      - name: Build (local, pour scanner)
        uses: docker/build-push-action@c3c9e263c25d99ce0380d002d59b67737d91b0dc # v7.4.0
        with:
          context: ./api
          file: ./api/Dockerfile.multi
          load: true
          tags: demo-api:ci

      - name: Scan Trivy
        uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0
        with:
          image-ref: demo-api:ci
          severity: CRITICAL,HIGH
          ignore-unfixed: true
          exit-code: "1" # la CI echoue si une CVE HIGH/CRITICAL corrigeable est trouvee
          format: table
```

Elle tourne à chaque push sur main, sur les tags `v*` et sur les pull requests. `exit-code: "1"` fait échouer le job dès qu'une CVE HIGH/CRITICAL corrigeable est trouvée.

J'ai épinglé les actions par leur SHA de commit au lieu du tag (le numéro de version est en commentaire), parce qu'un tag peut être déplacé vers un autre code alors qu'un SHA non.

## Les runs (rouge puis vert)

| Tag | Ce qu'il y a dedans | Résultat |
|---|---|---|
| `v1.0.0` | la version corrigée | ✅ [run vert](https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/actions/runs/40670018785) |
| `v1.0.1` | **régression volontaire** : retour à `node:22.11-alpine` sans `apk upgrade` | ❌ [run rouge](https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/actions/runs/40670284854), échoue à l'étape "Scan Trivy" |
| `v1.0.2` | retour à `node:22.23.4-alpine3.24` | ✅ [run vert](https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/actions/runs/40670569755) |

Pour la régression, changer juste le tag de base suffisait pas : avec le `apk upgrade` et npm supprimé, le vieux tag passait quand même le scan (exit 0, testé en local). J'ai donc aussi enlevé la ligne `RUN apk upgrade ...`, ce qui revient au Dockerfile d'avant la correction. Là Trivy trouve 52 CVE et la CI devient rouge.

J'ai mis la régression sur une branche à part et poussé seulement le tag `v1.0.1`, pour pas casser `main`.

## Quiz

1. scanner une image (et un repo) pour lister les CVE connues des paquets OS et des dépendances
2. paquets de l'OS de base, et dépendances applicatives
3. en mettant à jour ou en changeant l'image de base (tag plus récent, apk/apt upgrade)
4. masquer les CVE qui ont pas encore de correctif
5. un statut "fixed" avec une "Fixed Version"
6. lancer Trivy avec exit-code: 1 sur HIGH,CRITICAL
7. elle accumule les CVE avec le temps, il faut rebuild et bumper le tag
8. une alternative intégrée à Docker pour lister les CVE d'une image
9. le système de fichiers d'un repo (trivy fs) et les fichiers d'infra (trivy config)
10. un SBOM (inventaire des composants de l'image)
