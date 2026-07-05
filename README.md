# Calendar

A calendar app: React (Vite) frontend, Express + Postgres backend, containerized with Docker and deployable to Kubernetes via Helm.

## Project structure

```
package.json         npm workspaces root: ["backend", "frontend"] — single
                      package-lock.json/node_modules for both projects
nx.json               NX config (task caching, target defaults) — see
                      "Monorepo tooling (NX)" below
.dockerignore         single root-level ignore file (both Dockerfiles now
                      build from repo-root context, see below)

backend/            Express API
  app.js             Express app (routes, middleware, error handling) — imported by tests
  server.js          entrypoint: imports app.js, starts listening
  controllers/        one file per resource (user, calendar, event, tag) — list/get/create/update/remove
  routes/              thin Express routers wiring HTTP verbs to controllers
  migrations/          node-pg-migrate SQL migrations (schema lives here, not in app code)
  tests/               integration tests (node:test + supertest) against a real Postgres
  Dockerfile

frontend/            React (Vite) app
  src/
    App.jsx            top-level state + layout
    api.js              fetch client, one object per resource (usersApi, calendarsApi, eventsApi, tagsApi)
    components/          CalendarGrid, EventModal, Sidebar
    dateUtils.js         month-grid date helpers
  nginx.conf           serves the built app, proxies /api/ to the backend container
  Dockerfile           multi-stage build -> nginx

helm/calendar/       Helm chart for deploying to Kubernetes
  templates/
    backend-deployment.yaml / backend-service.yaml
    frontend-deployment.yaml / frontend-service.yaml / frontend-configmap.yaml  (templates nginx.conf's backend hostname)
    migration-job.yaml    pre-install/pre-upgrade hook: runs migrations once before app pods roll out
    ingress.yaml
  values.yaml          image repos/tags, replica counts, resources, ingress config

local-dev/           local-only files for testing the Helm chart against a kind cluster
  kind-postgres.yaml   throwaway Postgres + Secret (the chart itself assumes an external managed DB, e.g. RDS)
  values-kind.yaml     Helm value overrides for local image tags + disabled ingress

docker-compose.yml   local dev stack: db -> migrate -> backend -> frontend
.github/workflows/ci.yml   tests on every push/PR; builds + pushes images to GHCR on push to main
```

## Running locally (Docker Compose)

```
docker compose up --build
```

This starts, in order: Postgres (`db`), a one-shot migration runner (`migrate`), the API (`backend`, port 3001), and the frontend (`frontend`, port 80).

Open **http://localhost**.

Tear down (and drop the Postgres volume, for a clean slate):
```
docker compose down -v
```

## Monorepo tooling (NX)

`backend` and `frontend` are managed as an npm workspace (single root `package-lock.json`), with
[NX](https://nx.dev) layered on top for task running. NX infers its targets directly from each
project's existing `package.json` scripts — no extra config needed. Project names come from each
`package.json`'s `"name"` field (the backend project is `calendar-backend`, not `backend`).

```
npm install                          # installs both workspaces at once
npx nx show projects                  # list detected projects
npx nx show project calendar-backend   # see a project's inferred targets
npx nx run frontend:build              # run a single target (results are cached locally)
npx nx run calendar-backend:test        # requires a running, migrated Postgres — see below
```

Because `backend` and `frontend` share no code or dependencies today, NX's caching/affected-detection
benefits are modest at this size — it's set up here as groundwork for the CI pipeline (`nx affected`)
and to learn the tool, not because the repo needs it yet.

## Running the backend tests

Tests are real integration tests against a real, migrated Postgres — no mocking.

```
docker compose up -d db
docker compose run --rm migrate
cd backend
DATABASE_URL=postgres://calendar:calendar@localhost:5432/calendar npm test
```

The same steps run automatically in CI on every push and pull request.

## Database migrations

Schema changes are managed by [node-pg-migrate](https://github.com/salsita/node-pg-migrate), not applied by the app at boot (that would race across multiple backend replicas). Migration files live in `backend/migrations/`.

```
cd backend
npm run migrate:create -- <name>   # scaffold a new migration
npm run migrate:up                  # apply pending migrations
npm run migrate:down                 # roll back the last migration
```

## Deploying to Kubernetes

The chart assumes an external managed Postgres (e.g. AWS RDS) reachable via a `DATABASE_URL` already present in a Secret — it does not deploy its own database.

```
helm install calendar ./helm/calendar \
  --set backend.existingSecret=<your-secret-name> \
  -f <your-environment-values.yaml>
```

### Testing the chart locally with kind

```
kind create cluster --name calendar-dev

docker build -f backend/Dockerfile -t calendar-backend:local .
docker build -f frontend/Dockerfile -t calendar-frontend:local .
kind load docker-image calendar-backend:local calendar-frontend:local --name calendar-dev

kubectl apply -f local-dev/kind-postgres.yaml

helm install calendar ./helm/calendar -f local-dev/values-kind.yaml

kubectl port-forward svc/calendar-calendar-frontend 8080:80
```

Then open **http://localhost:8080**.

## CI/CD

`.github/workflows/ci.yml`:
- **On every push/PR**: spins up a Postgres service container, runs migrations, runs the backend test suite.
- **On push to `main`** (only if tests pass): builds both images, tags them with the git commit SHA and `latest`, pushes to `ghcr.io/<owner>/calendar-backend` and `.../calendar-frontend`. Use the SHA tag for anything real — `latest` is a convenience pointer only.
