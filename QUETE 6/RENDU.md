# Quête 6 - Les réseaux

Code de cette étape : tag `quete-6` (https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API/tree/quete-6)

Script : [`reseaux_erion_parduzi.sh`](reseaux_erion_parduzi.sh)

L'idée c'est de mettre la base derrière l'API :
- `demo_front` : l'API, publiée sur le port 8080
- `demo_back` : l'API et la base
- la base est seulement sur `demo_back` et n'a pas de `-p`, donc personne dehors ni sur demo_front peut la joindre

Aucun conteneur n'est sur le bridge par défaut.

## Pour tester

```bash
git clone https://github.com/ynov-x-anthony/PARDUZI_ERION_DEMO_API.git
cd PARDUZI_ERION_DEMO_API
git checkout quete-6
bash "QUETE 6/reseaux_erion_parduzi.sh"
```

Il faut le lancer depuis la racine du repo parce qu'il build l'image depuis `./api` et monte `db/init.sql` pour avoir les produits de démo. Sur Windows ça marche avec Git Bash.

Pour mettre l'API sur les deux réseaux, je la lance sur `demo_front` et ensuite je fais `docker network connect demo_back demo-api` (on peut pas donner deux `--network` au `docker run` de façon simple).

## Exécution

```
== build de l'image demo-api:1.0
== creation des reseaux
7a747419613cf26b59ee54ac623bb6de8b4e6e665159ab7991db2eb01b6be09e
21958a0c2251e89055c41d29a740ee9cccaac9c66b79592270b1a500886a18a1
== base sur demo_back uniquement, sans -p
== api sur demo_front + demo_back, publiee sur 8080

== reseaux de chaque conteneur
demo-db : demo_back 
demo-api : demo_back demo_front 
ports publies demo-db  : []
ports publies demo-api : [3000/tcp -> 0.0.0.0:8080 3000/tcp -> [::]:8080 ]

== adresses IPv4
-- demo-db
demo_back : <nil> 172.21.0.2

-- demo-api
demo_back : {invalid IP invalid IP []} 172.21.0.3
demo_front : <nil> 172.20.0.2

== demo-api joint demo-db par son nom
172.21.0.2        demo-db  demo-db

== conteneur tiers sur demo_front seulement -> doit echouer
nc: bad address 'demo-db'
echec attendu : demo-db n'est pas joignable depuis demo_front

== pour comparer : un conteneur tiers sur demo_back y arrive
demo-db (172.21.0.2:5432) open

== curl localhost:8080/products
[{"id":3,"name":"T-shirt conteneur","price_cents":1990,"created_at":"2026-10-26T18:02:58.954Z"},{"id":2,"name":"Mug Docker","price_cents":990,"created_at":"2026-10-26T18:02:58.954Z"},{"id":1,"name":"Sticker Demo","price_cents":150,"created_at":"2026-10-26T18:02:58.954Z"}]

== nettoyage
demo-api
demo-db
demo_front
demo_back
```

Ce qu'on voit :
- demo-api trouve demo-db par son nom (`getent hosts demo-db` → 172.21.0.2) grâce au DNS interne de Docker sur les réseaux perso
- le conteneur alpine branché que sur demo_front n'arrive même pas à résoudre le nom (`bad address 'demo-db'`), il n'a aucun réseau en commun avec la base
- j'ai rajouté le même test depuis demo_back pour comparer : là le port 5432 est ouvert
- demo-db n'a aucun port publié, demo-api a 8080 -> 3000
- l'API a une IP par réseau (172.20.x sur demo_front, 172.21.x sur demo_back)
- `/products` renvoie bien les 3 produits du init.sql

Le `IPAMConfig` vaut `<nil>` (ou vide) parce que j'ai pas fixé d'IP statique, c'est Docker qui les attribue. L'adresse est dans `IPAddress`.

## Quiz

1. docker network ls
2. non, seulement par IP (le DNS par nom il faut un réseau perso)
3. host
4. --driver
5. docker network connect
6. rendre un service du conteneur joignable depuis l'hôte / l'extérieur
7. dans chaque conteneur d'un réseau perso, à l'adresse 127.0.0.11
8. il documente le port, il faut -p (ou ports:) pour le publier
9. non, l'API passe par le réseau interne, publier la base l'exposerait pour rien
10. s'ils partagent au moins un réseau
