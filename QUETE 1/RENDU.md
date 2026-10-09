# Quête 1 – Découverte de Docker

> Version figée de cette quête : tag [`quete-1`](https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/tree/quete-1)

## Comment tester

Aucun fichier du repo n'est nécessaire, tout se fait avec l'image publique `postgres:16-alpine` :

```bash
docker run -d --name demo-db -e POSTGRES_USER=demo -e POSTGRES_PASSWORD=demo -e POSTGRES_DB=demo postgres:16-alpine
docker logs demo-db 2>&1 | grep "ready to accept connections"
docker exec -it demo-db psql -U demo -d demo -c "CREATE TABLE products (id serial primary key, name text, price_cents int);" -c "INSERT INTO products (name, price_cents) VALUES ('Sticker Démo', 150);" -c "SELECT * FROM products;" -c "\dt"
docker stop demo-db && docker rm demo-db
```

## Quiz

1. Docker Hub : **propose des images docker**, **est un site web**
2. Docker Engine : **est une application client-serveur**, **contient le serveur dockerd**, **fournit une CLI**
3. `docker ps` : **affiche la liste des conteneurs en cours d'exécution**
4. `docker images` : **est un alias de docker image ls**, **affiche les images disponibles localement**
5. Sur macOS/Windows : **fait tourner un noyau Linux dans une machine virtuelle**, **publie les ports des conteneurs sur localhost**
6. Tag `latest` : **est juste le tag utilisé par défaut**, **peut pointer vers une version ancienne**
7. PID 1 terminé : **il passe à l'état "Exited"**, **il reste visible avec "docker ps -a"**

## Challenge – PostgreSQL dans un conteneur

### Commandes

```bash
docker pull postgres:16-alpine
docker run -d --name demo-db -e POSTGRES_USER=demo -e POSTGRES_PASSWORD=demo -e POSTGRES_DB=demo postgres:16-alpine
docker ps
docker logs demo-db
docker exec -it demo-db psql -U demo -d demo
```

```sql
CREATE TABLE products (id serial primary key, name text, price_cents int);
INSERT INTO products (name, price_cents) VALUES ('Sticker Démo', 150);
SELECT * FROM products;
\dt
\q
```

```bash
docker stop demo-db && docker rm demo-db
```

### `docker ps`

```
CONTAINER ID   IMAGE                COMMAND                  CREATED         STATUS         PORTS      NAMES
64eb4ad26141   postgres:16-alpine   "docker-entrypoint.s…"   7 seconds ago   Up 6 seconds   5432/tcp   demo-db
```

### `SELECT * FROM products;`

```
 id |     name     | price_cents
----+--------------+-------------
  1 | Sticker Démo |         150
(1 row)
```

### `\dt`

```
         List of relations
 Schema |   Name   | Type  | Owner
--------+----------+-------+-------
 public | products | table | demo
(1 row)
```

### 3 dernières lignes de `docker logs demo-db`

```
2026-10-08 13:22:19.998 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2026-10-08 13:22:20.032 UTC [57] LOG:  database system was shut down at 2026-10-08 13:22:19 UTC
2026-10-08 13:22:20.048 UTC [1] LOG:  database system is ready to accept connections
```
