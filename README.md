# Calendar

A calendar app: React (Vite) frontend, Express + Postgres backend, containerized with Docker and deployable to Kubernetes via Helm.

## Project structure

```
package.json         npm workspaces root: ["backend", "frontend"] — single
                      package-lock.json/node_modules for both projects
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

helm/calendar/       Umbrella Helm chart for deploying to Kubernetes
  Chart.yaml           declares backend/frontend as local subchart dependencies
  values.yaml          cross-cutting config (ingress, migration, global.backend.servicePort)
  templates/
    migration-job.yaml   pre-install/pre-upgrade hook: runs migrations once before app pods roll out
    ingress.yaml
    _helpers.tpl          cross-chart-safe naming helpers (see file's own comment for why)
  charts/backend/       independent subchart: Deployment, Service, own values.yaml (image/resources/etc)
  charts/frontend/      independent subchart: Deployment, Service, ConfigMap (nginx.conf), own values.yaml

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

## Monorepo tooling

`backend` and `frontend` are managed as a single npm workspace (`package.json`'s `"workspaces"`
field) — one root `package-lock.json`/`node_modules` for both, installed with a single `npm
install` from the repo root. Each project's own scripts still run normally from its own folder
(`cd backend && npm test`, `cd frontend && npm run build`, etc).

NX was evaluated and set up briefly here (task graph, inferred targets, local caching) but removed:
with only 2 projects that share zero code or dependencies, NX's caching/affected-detection benefits
didn't justify the added tooling for this repo's size. CI instead uses two independent GitHub
Actions workflows (see CI/CD below) rather than an NX-orchestrated pipeline.

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

kubectl port-forward svc/calendar-frontend 8080:80
```

Then open **http://localhost:8080**.

## CI/CD

Two independent workflows, each triggered only by changes relevant to it (via `paths:` filters —
a PR that only touches `frontend/` never runs backend CI, and vice versa). Both watch the root
`package.json`/`package-lock.json` too, since that's the shared npm workspace lockfile.

`.github/workflows/backend-ci.yml`:
- **On every push/PR touching `backend/**` or the root lockfile**: spins up a Postgres service container, runs migrations, runs the backend test suite.
- **On push to `main`** (only if tests pass): builds the backend image and pushes it to Amazon ECR.

`.github/workflows/frontend-ci.yml`:
- **On every push/PR touching `frontend/**` or the root lockfile**: lints (`oxlint`) and builds (`vite build`) the frontend.
- **On push to `main`** (only if lint/build pass): builds the frontend image and pushes it to Amazon ECR.

Both images are tagged with the git commit SHA and `latest` — use the SHA tag for anything real,
`latest` is a convenience pointer only.

### Authentication: GitHub OIDC, no stored AWS keys

Both `build-and-push` jobs authenticate to AWS via **OpenID Connect**, not long-lived access keys:
GitHub issues a short-lived signed token for the running job (`permissions: id-token: write`),
`aws-actions/configure-aws-credentials` exchanges it for temporary AWS credentials by assuming an
IAM role, and `aws-actions/amazon-ecr-login` uses those to log Docker in to ECR. The role's trust
policy only allows `push` events on `main` in this exact repo to assume it — a PR, a fork, or a
different branch is rejected by AWS itself before the role's permissions even matter.

The AWS side of this (the ECR repositories, the OIDC provider, and the IAM role) is provisioned by
Terraform in `infra/bootstrap/` — see that folder's README. The workflows reference the role ARN
and AWS region via GitHub Actions repository **Variables** (`AWS_GITHUB_ACTIONS_ROLE_ARN`,
`AWS_REGION`) rather than hardcoding them, since neither value is secret but both are
repo/account-specific.
