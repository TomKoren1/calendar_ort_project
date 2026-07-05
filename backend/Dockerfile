FROM node:22-alpine

WORKDIR /app

# Copy just the workspace manifests first so this layer only invalidates when
# a package.json/lockfile actually changes, not on every source edit.
COPY package.json package-lock.json ./
COPY backend/package.json backend/package.json
COPY frontend/package.json frontend/package.json
RUN npm ci --workspace=calendar-backend --omit=dev

COPY backend/ backend/

WORKDIR /app/backend

EXPOSE 3001

CMD ["node", "server.js"]
