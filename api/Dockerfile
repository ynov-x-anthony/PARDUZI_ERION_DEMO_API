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
