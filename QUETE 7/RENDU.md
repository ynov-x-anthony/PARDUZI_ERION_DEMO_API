# Quête 7 - Compose

Code de cette étape : tag `quete-7` (https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/tree/quete-7)

Fichiers : [`compose.yml`](../compose.yml), [`.env.example`](../.env.example), [`.gitignore`](../.gitignore)

Toute la stack (api + postgres + adminer) se lance avec une seule commande au lieu des `docker run` des quêtes d'avant.

## Pour tester

```bash
git clone https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API.git
cd PARDUZI_ERION_DEMO_API
git checkout quete-7

cp .env.example .env
mkdir -p secrets && echo "un-mot-de-passe" > secrets/db_password.txt
docker compose up -d --build --wait

curl -s localhost:8080/products   # l'api
# http://localhost:8081            # adminer (serveur : db, user : demo)

docker compose down -v
```

Ou `sh "QUETE 7/test.sh"` qui fait tout ça (il crée le .env et un mot de passe aléatoire s'ils existent pas) et vérifie le reste.

## compose.yml

```yaml
name: demo-api

services:
  api:
    build: ./api
    image: demo-api:compose
    environment:
      PGHOST: db
      PGUSER: ${POSTGRES_USER}
      PGDATABASE: ${POSTGRES_DB}
      # le mot de passe est lu depuis le secret, pas en clair
      PGPASSWORD_FILE: /run/secrets/db_password
    secrets: [db_password]
    ports:
      - "${API_PORT:-8080}:3000"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    # on garde le durcissement de la quete 3
    read_only: true
    tmpfs: ["/tmp:size=16m"]
    cap_drop: ["ALL"]
    security_opt: ["no-new-privileges:true"]

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets: [db_password]
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 3s
      retries: 10
    restart: unless-stopped

  adminer:
    image: adminer:4
    ports:
      - "${ADMINER_PORT:-8081}:8080"
    depends_on: [db]
    restart: unless-stopped

volumes:
  pgdata:

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

Ce que j'ai mis :
- `api` est build depuis `./api`, publiée sur `${API_PORT:-8080}`, attend que la base soit healthy (`condition: service_healthy`) et a `restart: unless-stopped`
- `db` n'a pas de `ports:`, elle a le volume nommé `pgdata`, le bind mount de `init.sql` et un healthcheck avec `pg_isready`
- `adminer` est sur `${ADMINER_PORT:-8081}`
- `name: demo-api` en haut pour que le projet s'appelle pareil peu importe le nom du dossier (le mien s'appelle "EXERCICE DOCKER")
- j'ai remis sur l'api le durcissement de la quête 3 (read_only, cap_drop, no-new-privileges)

## Les variables et le secret (bonus)

`.env.example` est commité, `.env` est dans le `.gitignore` :

```
# a copier en .env : cp .env.example .env
POSTGRES_USER=demo
POSTGRES_DB=demo
API_PORT=8080
ADMINER_PORT=8081
# le mot de passe n'est pas ici : il est dans secrets/db_password.txt (pas commite)
#   mkdir -p secrets && echo "un-mot-de-passe" > secrets/db_password.txt
```

Pour le bonus, le mot de passe passe par Docker Secrets : il est dans `secrets/db_password.txt` (dossier ajouté au `.gitignore`) et monté dans `/run/secrets/db_password`.
- postgres sait lire `POSTGRES_PASSWORD_FILE` directement
- pour l'api, le code lisait que `PGPASSWORD`, donc j'ai ajouté une petite fonction dans `api/db.js` qui lit le fichier si `PGPASSWORD_FILE` est défini (sinon ça marche comme avant avec `PGPASSWORD`)

Du coup le mot de passe apparaît dans aucune variable d'environnement, ni dans le compose.yml, ni dans le .env.

## Résultats (sortie de test.sh)

```
== docker compose config (extrait)
        condition: service_healthy
      PGDATABASE: demo
      PGHOST: db
      PGPASSWORD_FILE: /run/secrets/db_password
      PGUSER: demo
        published: "8080"
    secrets:
      - source: db_password
        target: /run/secrets/db_password

== up
 Container demo-api-adminer-1 Healthy 
 Container demo-api-adminer-1 Started 
 Container demo-api-api-1 Healthy 
 Container demo-api-api-1 Started 
 Container demo-api-db-1 Healthy 
 Container demo-api-db-1 Started 
SERVICE   STATUS                    PORTS
adminer   Up 11 seconds             0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp
api       Up 6 seconds (healthy)    0.0.0.0:8080->3000/tcp, [::]:8080->3000/tcp
db        Up 12 seconds (healthy)   5432/tcp

== /products
[{"id":3,"name":"T-shirt conteneur","price_cents":1990,"created_at":"2026-10-28T09:52:52.785Z"},{"id":2,"name":"Mug Docker","price_cents":990,"created_at":"2026-10-28T09:52:52.785Z"},{"id":1,"name":"Sticker Demo","price_cents":150,"created_at":"2026-10-28T09:52:52.785Z"}]
== /ready
{"status":"READY"}
== adminer
HTTP/1.1 200 OK

== le mot de passe n'est pas en clair dans les variables
-- variables PG de l'api :
PGDATABASE=demo
PGHOST=db
PGPASSWORD_FILE=/run/secrets/db_password
PGUSER=demo
-- variables POSTGRES de la db :
POSTGRES_DB=demo
POSTGRES_PASSWORD_FILE=/run/secrets/db_password
POSTGRES_USER=demo
-- le secret est un fichier monte :
total 0
-rwxrwxrwx    1 root     root            24 Oct 27 14:27 db_password

== la db n'est pas publiee
ports db : 5432/tcp  (pas de 0.0.0.0:xxxx, donc rien de publie sur l'hote)

== persistance : ajout d'un produit, down, up
{"id":4,"name":"Ajout compose","price_cents":500,"created_at":"2026-10-28T09:53:05.980Z"}
 Container demo-api-api-1 Removed 
 Container demo-api-adminer-1 Removed 
 Container demo-api-db-1 Removed 
 Network demo-api_default Removed 
DRIVER    VOLUME NAME
local     demo-api_pgdata
[{"id":4,"name":"Ajout compose","price_cents":500,"created_at":"2026-10-28T09:53:05.980Z"},{"id":3,"name":"T-shirt conteneur","price_cents":1990,"created_at":"2026-10-28T09:52:52.785Z"},{"id":2,"name":"Mug Docker","price_cents":990,"created_at":"2026-10-28T09:52:52.785Z"},{"id":1,"name":"Sticker Demo","price_cents":150,"created_at":"2026-10-28T09:52:52.785Z"}]

== down -v (supprime aussi le volume)
 Volume demo-api_pgdata Removing 
 Network demo-api_default Removing 
 Volume demo-api_pgdata Removed 
 Network demo-api_default Removed 
```

Ce qu'on voit :
- les 3 services démarrent, la db et l'api passent en healthy, l'api a attendu la db avant de démarrer
- /products renvoie les produits du init.sql, adminer répond en 200
- dans les variables il y a juste `PGPASSWORD_FILE` / `POSTGRES_PASSWORD_FILE`, pas le mot de passe
- la db a juste `5432/tcp` sans redirection, donc elle est pas publiée sur l'hôte
- après un `down` puis `up`, le produit ajouté est toujours là (le volume est gardé). Avec `down -v` le volume est supprimé

## Quiz

1. définir et lancer une application multi-conteneurs depuis un seul fichier
2. docker compose up
3. non, c'est obsolète avec Compose v2
4. docker compose config
5. docker compose up -d
6. image
7. depends_on
8. le conteneur db est lancé, pas qu'il soit prêt
9. un healthcheck sur db + depends_on avec condition: service_healthy
10. avant le lancement, depuis le .env ou le shell
11. il sert à l'interpolation ${} et entre pas tout seul dans les conteneurs
12. -v supprime aussi les volumes nommés (donc les données)
13. en clair dans un .env commité sur Git
