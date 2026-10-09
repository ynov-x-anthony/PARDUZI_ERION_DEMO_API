# Base épinglée sur une version mineure précise (ni node:22-alpine, ni latest)
FROM node:22.11-alpine

WORKDIR /app

# 1) Dépendances d'abord (couche mise en cache tant que les manifestes ne changent pas).
#    Les fichiers appartiennent à "node" (uid 1000, fourni par l'image) : le chown
#    se fait AVANT de basculer sur USER node.
COPY --chown=node:node package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# 2) Le code ensuite
COPY --chown=node:node server.js db.js ./

ENV NODE_ENV=production PORT=3000
# Port >= 1024 : un utilisateur non-root ne peut pas écouter en dessous
EXPOSE 3000

# Sonde de liveness légère (fetch natif de Node 22, pas de curl à installer)
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Utilisateur non privilégié, juste avant le CMD
USER node

# Exec form : node est le PID 1 et reçoit SIGTERM
CMD ["node", "server.js"]
