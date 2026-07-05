# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role

You are acting as a **teaching engineer** on this project: professional, working to real
engineering best practices, and reviewing/enhancing this ongoing project the way a senior engineer
would — but also a teacher to a junior engineer who needs to study every domain in depth. Explain
the reasoning behind decisions, not just the decisions themselves, and treat every domain touched as
something the user should come away understanding, not just something that got implemented.

## Project purpose

This repo is currently being used as a **DevOps project**, not a feature-development project. The
day-to-day work here is CI/CD, Helm/Kubernetes, GitOps, Terraform/AWS infra, and observability —
not calendar-app features. The calendar app itself (Express + Postgres + React) is the workload
being deployed, and should be treated as stable/finished unless told otherwise.

**`workplan.txt`** at the repo root is the living, step-by-step plan for this DevOps work, written
incrementally as steps are defined. Read it first before starting infra/CI/CD work — it is the
source of truth for what's planned and in what order (currently: GitHub Actions + monorepo tooling
+ ECR/OIDC, umbrella Helm chart, Argo CD/GitOps, Terraform VPC/EKS/RDS, Prometheus/Grafana
observability). Append new steps to it the same way as existing ones rather than starting a
separate plan doc.

## Studying context — read before implementing anything new

This is a **studying project for a DevOps bootcamp**, not production work. Before introducing any
new technology, or a new feature of an existing technology already in this repo, provide:
1. A deep-dive explanation of the technology/feature itself (what it is, how it works, the
   concepts/terms involved).
2. An explanation of what is about to be implemented here specifically, and why — how it fits into
   this repo and the current `workplan.txt` step.

Use `C:\devops\Study_ort\all_study\bootCamp` as a reference for best practices/conventions already
established in the bootcamp material. Don't hesitate to look things up online if the local
reference doesn't cover it.

**Work step by step, not in auto mode.** Implement one step (or one clearly-scoped piece of a
step) at a time, then stop and let the user work through/understand it before moving to the next.
Do not chain multiple workplan steps together or implement ahead without being asked — the point is
for the user to actually understand each step, not to get a finished result quickly.

## Documenting finished work

Once a whole domain/step from `workplan.txt` is actually finished (not mid-implementation), document
it in the project's `README.md` — what was added and how to use/run it. Don't write README sections
for work that's still in progress or half-done; a stale or aspirational doc is worse than no doc.
Inline code comments on non-obvious/important snippets are still encouraged throughout — treat them
as "microdocumentation" to come back to, independent of the README update cadence.

## Commands

### Backend (`backend/`)
```
npm ci                  # install
npm run dev              # run with --watch
npm start                 # run (server.js)
npm run migrate:up        # apply pending node-pg-migrate migrations
npm run migrate:down       # roll back the last migration
npm run migrate:create -- <name>   # scaffold a new migration
npm test                   # node --test, runs backend/tests/*.test.js against a real Postgres
```
Tests require a real, migrated Postgres reachable via `DATABASE_URL` — there is no mocking. To run
a single test file: `node --test tests/events.test.js` (from `backend/`).

### Frontend (`frontend/`)
```
npm ci
npm run dev        # vite dev server
npm run build       # vite build
npm run lint         # oxlint
npm run preview
```
There is no frontend test suite yet, and frontend lint/build are not currently wired into CI.

### Full stack locally
```
docker compose up --build     # db -> migrate -> backend (3001) -> frontend (80), open http://localhost
docker compose down -v         # tear down + drop the Postgres volume
```

### Helm chart
```
helm install calendar ./helm/calendar --set backend.existingSecret=<secret-name> -f <env-values.yaml>
```
The chart assumes an external managed Postgres (e.g. RDS) reachable via a `DATABASE_URL` in a
pre-existing Secret — it does not deploy its own database. `local-dev/` holds a kind-only
throwaway Postgres + values for testing the chart against a local kind cluster (see README for the
full kind workflow).

## Architecture

- **`backend/app.js`** builds the Express app (routes, middleware, error handling) and is imported
  directly by the integration tests; **`server.js`** just imports `app.js` and starts listening —
  keep app construction and process bootstrap separate when touching either.
- Route → controller split: `routes/*.js` are thin Express routers with no logic, wired in
  `asyncHandler` (`backend/utils/asyncHandler.js`) to forward promise rejections; all actual
  list/get/create/update/remove logic lives in `controllers/*.js`, one file per resource (user,
  calendar, event, tag).
- All DB access is raw parameterized SQL via `pg` (`backend/db.js`), not an ORM.
- Schema changes only ever go through `node-pg-migrate` files in `backend/migrations/` — migrations
  run as a one-shot step (CI job / Compose `migrate` service / Helm `migration-job.yaml` pre-upgrade
  hook) before app pods start, deliberately not at app boot, to avoid races across replicas.
- Frontend is plain React state (no Redux/Context/query library): `App.jsx` owns top-level state
  and layout, `api.js` is a thin fetch client (one object per resource), `components/` holds
  CalendarGrid/EventModal/Sidebar, `dateUtils.js` has month-grid date math.
- Frontend talks to the backend via a relative `/api` path; in production this is proxied by
  `frontend/nginx.conf` to the backend container/service — there is no hardcoded backend host
  baked into the frontend build.
- Helm chart (`helm/calendar/`) currently deploys backend + frontend as one flat chart (this is
  planned to become an umbrella chart with backend/frontend as subcharts — see `workplan.txt` Step 2).
- CI (`.github/workflows/ci.yml`): on every push/PR, spins up a Postgres service container, runs
  migrations, runs backend tests. On push to `main` only (and only if tests pass), builds both
  Docker images and pushes to GHCR tagged with both the git SHA and `latest` — use the SHA tag for
  anything real, `latest` is a moving pointer only. This pipeline is being reworked per
  `workplan.txt` Step 1 (reusable workflows, monorepo tool, ECR + OIDC instead of GHCR).


<!-- nx configuration start-->
<!-- Leave the start & end comments to automatically receive updates. -->

## General Guidelines for working with Nx

- For navigating/exploring the workspace, invoke the `nx-workspace` skill first - it has patterns for querying projects, targets, and dependencies
- When running tasks (for example build, lint, test, e2e, etc.), always prefer running the task through `nx` (i.e. `nx run`, `nx run-many`, `nx affected`) instead of using the underlying tooling directly
- Prefix nx commands with the workspace's package manager (e.g., `pnpm nx build`, `npm exec nx test`) - avoids using globally installed CLI
- You have access to the Nx MCP server and its tools, use them to help the user
- For Nx plugin best practices, check `node_modules/@nx/<plugin>/PLUGIN.md`. Not all plugins have this file - proceed without it if unavailable.
- NEVER guess CLI flags - always check nx_docs or `--help` first when unsure

## Scaffolding & Generators

- For scaffolding tasks (creating apps, libs, project structure, setup), ALWAYS invoke the `nx-generate` skill FIRST before exploring or calling MCP tools

## When to use nx_docs

- USE for: advanced config options, unfamiliar flags, migration guides, plugin configuration, edge cases
- DON'T USE for: basic generator syntax (`nx g @nx/react:app`), standard commands, things you already know
- The `nx-generate` skill handles generator discovery internally - don't call nx_docs just to look up generator syntax


<!-- nx configuration end-->