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

## GitOps deployment (Argo CD)

The commands above still work for a one-off manual install, but the kind cluster is actually kept
in sync by **Argo CD** using an app-of-apps pattern — Git, not a person running `helm upgrade`, is
the source of truth for what's deployed.

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts
```

(`--server-side` matters: plain `kubectl apply` fails on the `applicationsets.argoproj.io` CRD,
which is too large for the client-side `last-applied-configuration` annotation.)

Bootstrap (applied once, by hand):
```
kubectl apply -f argocd/bootstrap/root-application.yaml
```

That one `Application` points at `argocd/applications/`, which currently holds
`calendar-appset.yaml` — an `ApplicationSet` (List generator, one `kind` environment today,
structured so a second real environment is a one-line addition later) that deploys `helm/calendar`
with `local-dev/values-kind-ecr.yaml`. Everything after that first `kubectl apply` is automatic:
push to `main` → CI builds and pushes the image to ECR → CI bumps the image tag in
`helm/calendar/charts/*/values.yaml` and pushes that to `main` → Argo detects the Git change and
syncs the cluster, with `selfHeal` reverting any manual drift and `prune` removing anything deleted
from Git.

Since kind has no AWS IAM identity of its own, pulling the private ECR images needs a manually
created pull secret (see `local-dev/values-kind-ecr.yaml`'s own comment for the exact command) —
this is a kind-only limitation; a real EKS cluster would use IRSA instead of a static, expiring
credential.

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

### The image tag is also written back to Git (real GitOps loop)

After pushing to ECR, each workflow also bumps `image.tag` in its own chart's `values.yaml`
(`helm/calendar/charts/backend/values.yaml` or `.../frontend/values.yaml`) to the commit SHA and
pushes that commit to `main` as `github-actions[bot]`. Without this, Argo CD (see GitOps section
above) would be watching a values file pinned to `tag: latest` — a moving pointer with nothing for
Argo to ever detect a change on. That bump commit's path doesn't match either workflow's `paths:`
filter, so it can't retrigger a CI loop.

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

## Observability (Prometheus + Grafana)

**kube-prometheus-stack** — Prometheus, Alertmanager, Grafana, node-exporter, and
kube-state-metrics, bundled as one Helm chart — is installed via Terraform
(`infra/modules/platform-addons/monitoring.tf`), in the same `terraform apply` as the EKS cluster
itself, not via Argo CD. This deliberately matches how every other platform addon in this repo is
installed (Karpenter, the AWS Load Balancer Controller, ingress-nginx): Argo CD is reserved for the
app workload, which changes on every CI push and benefits from continuous reconciliation.
kube-prometheus-stack doesn't change with app code — it's part of the cluster's baseline, the same
way Karpenter is.

No IAM policy or IRSA role is needed for this addon, unlike the others — Prometheus only talks to
the Kubernetes API (via its own in-cluster ServiceAccount/RBAC), never AWS APIs directly.

Prometheus and Grafana have no PersistentVolumes — a deliberate choice, consistent with this
project's ephemeral-by-design posture for `infra/environments/{dev,staging}` (RDS skips backups and
the final snapshot for the same reason): the whole environment is destroyed at the end of every
working session, so metrics/dashboards don't need to survive it. Prometheus's retention is trimmed
to 3 days accordingly (the chart's own default is 10).

```bash
# Grafana UI (admin / see `terraform output -raw grafana_admin_password` in infra/environments/<env>/)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# open http://localhost:3000

# Prometheus UI
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# open http://localhost:9090
```

### Scraping the backend

The backend exposes Prometheus-format metrics at `GET /metrics` (`backend/metrics.js`, via
`prom-client`): free process-level metrics (CPU, memory, event-loop lag, GC) plus two custom
metrics — `http_requests_total` and `http_request_duration_seconds`, both labeled
`method`/`route`/`status_code`. The `route` label always uses the *matched Express route pattern*
(e.g. `/api/events/:id`), never the raw request path — using the raw path would create a new label
value per unique ID and blow up Prometheus's cardinality; unmatched requests (404s) fall back to the
literal label `unmatched` for the same reason. `/metrics` is deliberately outside the `/api` prefix
that the rest of the backend lives under — it's scraped by Prometheus directly from the Kubernetes
Service, in-cluster, and never goes through the Ingress at all.

A `ServiceMonitor` (`helm/calendar/charts/backend/templates/servicemonitor.yaml`, gated by
`backend.serviceMonitor.enabled`) tells Prometheus to actually scrape it — matched by the backend
Service's own labels (a `ServiceMonitor` selects Services, then follows each Service's own selector
to find pods), scraping the named `http` port at `/metrics` every 30s. Disabled in
`local-dev/values-kind*.yaml`, since a local kind cluster has no Prometheus Operator CRDs installed
— applying a `ServiceMonitor` there would fail outright (the CRD doesn't exist), not just sit inert
the way an `HorizontalPodAutoscaler` does without `metrics-server`.
