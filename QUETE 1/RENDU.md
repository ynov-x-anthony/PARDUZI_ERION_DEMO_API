# Quête 1 - Découverte de Docker

Pas de code pour cette quête, on manipule juste une base Postgres dans un conteneur.

## Pour tester

```bash
docker run -d --name demo-db -e POSTGRES_USER=demo -e POSTGRES_PASSWORD=demo -e POSTGRES_DB=demo postgres:16-alpine
docker logs demo-db 2>&1 | grep "ready to accept connections"
docker exec -it demo-db psql -U demo -d demo
```

Puis dans psql :

```sql
CREATE TABLE products (id serial primary key, name text, price_cents int);
INSERT INTO products (name, price_cents) VALUES ('Sticker Démo', 150);
SELECT * FROM products;
\dt
\q
```

Et pour finir : `docker stop demo-db && docker rm demo-db`

## Mes résultats

docker ps :

```
CONTAINER ID   IMAGE                COMMAND                  CREATED         STATUS         PORTS      NAMES
64eb4ad26141   postgres:16-alpine   "docker-entrypoint.s…"   7 seconds ago   Up 6 seconds   5432/tcp   demo-db
```

SELECT * FROM products :

```
 id |     name     | price_cents
----+--------------+-------------
  1 | Sticker Démo |         150
(1 row)
```

\dt :

```
         List of relations
 Schema |   Name   | Type  | Owner
--------+----------+-------+-------
 public | products | table | demo
(1 row)
```

Les 3 dernières lignes de docker logs demo-db :

```
2026-10-08 13:22:19.998 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2026-10-08 13:22:20.032 UTC [57] LOG:  database system was shut down at 2026-10-08 13:22:19 UTC
2026-10-08 13:22:20.048 UTC [1] LOG:  database system is ready to accept connections
```

## Quiz

1. Docker Hub : propose des images docker / est un site web
2. Docker Engine : application client-serveur / contient dockerd / fournit une CLI
3. docker ps : liste les conteneurs en cours d'exécution
4. docker images : alias de docker image ls / affiche les images locales
5. macOS/Windows : noyau Linux dans une VM / ports publiés sur localhost
6. latest : tag par défaut / peut pointer vers une vieille version
7. PID 1 terminé : passe en Exited / reste visible avec docker ps -a
