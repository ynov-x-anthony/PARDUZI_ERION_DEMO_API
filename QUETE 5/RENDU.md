# Quête 5 - Les volumes

Code de cette étape : tag `quete-5` (https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/tree/quete-5)

Le but ici c'est que les données de Postgres survivent quand on supprime le conteneur de la base. Pour ça j'utilise un volume nommé `demo_pgdata` monté sur `/var/lib/postgresql/data`.

## Pour tester

```bash
git clone https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API.git
cd PARDUZI_ERION_DEMO_API
git checkout quete-5
sh "QUETE 5/test.sh"
```

Le script fait tout dans l'ordre :
1. montre qu'un fichier écrit dans un conteneur sans volume disparaît
2. lance postgres avec le volume `demo_pgdata` + l'API, et ajoute un produit avec un POST
3. supprime le conteneur de la base (`docker rm -f`), le recrée avec le même volume et vérifie que le produit est toujours là
4. affiche les infos du volume et son contenu (via un conteneur alpine, vu que sur Windows on a pas accès au Mountpoint)
5. fait une sauvegarde avec pg_dump
6. compare volume nommé / bind mount / tmpfs avec nginx

À la fin il supprime les conteneurs mais garde le volume `demo_pgdata` (`docker volume rm demo_pgdata` pour le supprimer).

## La commande pour la base

```bash
docker volume create demo_pgdata
docker run -d --name demo-db --network demo_net \
  -e POSTGRES_USER=demo -e POSTGRES_PASSWORD=demo -e POSTGRES_DB=demo \
  -v demo_pgdata:/var/lib/postgresql/data \
  -v "$(pwd)/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
  postgres:16-alpine
```

Le init.sql est en bind mount (c'est de la config qui vient du repo) et les données sont dans le volume nommé.

## Résultats

```
== 1. sans volume, les donnees partent avec le conteneur
coucou
-- nouveau conteneur, meme image :
cat: can't open '/data.txt': No such file or directory

== 2. volume nomme pour postgres
demo_pgdata
-- produits au depart (init.sql)
[{"id":3,"name":"T-shirt conteneur","price_cents":1990,"created_at":"2026-10-26T17:54:01.769Z"},{"id":2,"name":"Mug Docker","price_cents":990,"created_at":"2026-10-26T17:54:01.769Z"},{"id":1,"name":"Sticker Demo","price_cents":150,"created_at":"2026-10-26T17:54:01.769Z"}]
-- ajout d'un produit
{"id":4,"name":"Produit persistant","price_cents":4200,"created_at":"2026-10-26T17:54:06.922Z"}

== 3. on supprime le conteneur de la base et on le recree avec le meme volume
demo-db
-- init.sql n'est pas rejoue (le dossier de donnees n'est plus vide) :
PostgreSQL Database directory appears to contain a database; Skipping initialization
-- produits apres recreation
[{"id":4,"name":"Produit persistant","price_cents":4200,"created_at":"2026-10-26T17:54:06.922Z"},{"id":3,"name":"T-shirt conteneur","price_cents":1990,"created_at":"2026-10-26T17:54:01.769Z"},{"id":2,"name":"Mug Docker","price_cents":990,"created_at":"2026-10-26T17:54:01.769Z"},{"id":1,"name":"Sticker Demo","price_cents":150,"created_at":"2026-10-26T17:54:01.769Z"}]

== 4. infos sur le volume
DRIVER    VOLUME NAME
local     demo_pgdata
nom=demo_pgdata driver=local mountpoint=/var/lib/docker/volumes/demo_pgdata/_data
-- contenu vu depuis un conteneur jetable
PG_VERSION
base
global
pg_commit_ts
pg_dynshmem
pg_hba.conf
pg_ident.conf
pg_logical
-- suppression impossible tant qu'un conteneur l'utilise
Error response from daemon: remove demo_pgdata: volume is in use - [ab3b8cbafbb9b46e1bc8255ca705e3e18bb1d7f236ab80189952084fd88c6717]

== 5. sauvegarde avec pg_dump
COPY public.products (id, name, price_cents, created_at) FROM stdin;
1	Sticker Demo	150	2026-10-26 17:54:01.769242+00
2	Mug Docker	990	2026-10-26 17:54:01.769242+00
3	T-shirt conteneur	1990	2026-10-26 17:54:01.769242+00
4	Produit persistant	4200	2026-10-26 17:54:06.922724+00
\.


== 6. volume nomme vs bind mount (nginx)
-- volume nomme vide -> pre-rempli avec la page de l'image :
<title>Welcome to nginx!</title>
-- bind mount -> le dossier de l'hote cache celui de l'image :
<h1>Montage bind !</h1>
-- tmpfs :
tmpfs                    64.0M         0     64.0M   0% /tmp

== nettoyage fait, le volume demo_pgdata est garde (docker volume rm demo_pgdata pour le supprimer)
```

Ce qu'on voit :
- le produit "Produit persistant" (id 4) est toujours là après avoir supprimé et recréé le conteneur de la base
- au 2e démarrage, postgres affiche "Skipping initialization" : le init.sql est pas rejoué vu que le volume contient déjà une base (si on veut repartir de zéro il faut supprimer le volume)
- on peut pas supprimer le volume tant qu'un conteneur l'utilise
- avec nginx, le volume nommé vide est rempli avec la page par défaut de l'image, alors que le bind mount affiche mon fichier de l'hôte à la place

J'ai pas mis de `VOLUME` dans le Dockerfile de l'API, la persistance est déclarée au `docker run` avec un nom choisi (sinon ça crée des volumes anonymes qui s'accumulent).

Pour la sauvegarde j'ai utilisé pg_dump plutôt qu'un tar du volume, comme c'est conseillé pour une base qui tourne.

## Quiz

1. assurer la persistance des données au-delà du conteneur
2. docker volume create data_volume
3. docker volume ls
4. docker run -v data_volume:/data
5. docker volume rm data_volume
6. un volume vide est pré-rempli depuis l'image, un bind mount monte un dossier de l'hôte et cache le contenu de l'image
7. en montant le volume dans un conteneur jetable (docker run --rm -v vol:/v alpine ls /v)
8. il supprime aussi les volumes déclarés dans le compose, en plus des conteneurs et réseaux
