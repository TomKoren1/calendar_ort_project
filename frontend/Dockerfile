FROM node:22 AS build

WORKDIR /app

# Copy just the workspace manifests first so this layer only invalidates when
# a package.json/lockfile actually changes, not on every source edit.
COPY package.json package-lock.json ./
COPY backend/package.json backend/package.json
COPY frontend/package.json frontend/package.json
RUN npm ci --workspace=frontend

COPY frontend/ frontend/

WORKDIR /app/frontend
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/frontend/dist /usr/share/nginx/html
COPY frontend/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
