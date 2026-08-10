# crafter-infra

Central infrastructure and DevOps repository for **YACS** (Video Conference Management System).

This repository is the **master orchestrator** of the YACS platform. It doesn't contain application code itself — instead, it uses Docker and Docker Compose to containerize and run every microservice and backing service together, in a single, isolated environment:

- **Frontend** — `conference-web-app` (React/Vite SPA, served by Nginx)
- **BFF** — `conference-web-api` (NestJS Backend-for-Frontend)
- **Core Backends** — `account-manager` and `conference-manager` (Spring Boot / R2DBC)
- **Notification Service** — `notification-manager` (Spring Boot / MongoDB)
- **Backing services** — PostgreSQL (x2), Redis, Kafka (KRaft mode), MongoDB, Zipkin

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Configuration (.env)](#configuration-env)
- [Quick Start](#quick-start)
- [Services & Ports](#services--ports)
- [Networks & Volumes](#networks--volumes)
- [Useful Commands](#useful-commands)

## Architecture Overview

`docker-compose.yml` wires together the following containers on three bridge networks (`postgres`, `spring`, `redis`):

| Service | Role | Depends on |
|---|---|---|
| `account-postgres` | PostgreSQL DB for `account-manager` | — |
| `conference-postgres` | PostgreSQL DB for `conference-manager` | — |
| `redis` | Shared cache, used by `account-manager`, `conference-manager`, `conference-web-api` | — |
| `kafka` | Event bus (KRaft, single broker) used by all three Java services | — |
| `notification-mongodb` | MongoDB store for `notification-manager` | — |
| `zipkin` | Distributed tracing UI | — |
| `account-manager` | Account/auth core backend (Spring Boot, gRPC) | `account-postgres`, `redis`, `kafka` |
| `conference-manager` | Conference core backend (Spring Boot, gRPC) | `conference-postgres`, `redis`, `kafka` |
| `notification-manager` | Notification/email service (Spring Boot) | `notification-mongodb`, `kafka` |
| `conference-web-api` | BFF (NestJS) — aggregates gRPC calls to the two core backends | `redis`, `account-manager`, `conference-manager` |
| `conference-web-app` | Frontend SPA (Nginx) | `conference-web-api` |

Each application service (`account-manager`, `conference-manager`, `notification-manager`, `conference-web-api`, `conference-web-app`) is **built from its own sibling repository** using the `Dockerfile` that already exists in that repository — this repo only supplies the build context, environment variables and orchestration.

## Prerequisites

Make sure the following tools are installed on your machine:

- **Git**
- **Docker** (Engine 20.10+)
- **Docker Compose** (v2 plugin, i.e. `docker compose`, or standalone `docker-compose`)
- **Java 25+ & Maven** — required to build the three Java services' jars before their Docker images can be built (the `docker-image-build.sh` / `start-infra.sh` scripts will install Maven automatically if it's missing)
- **Node.js & npm** — required to build `conference-web-api` / `conference-web-app` images
- **AWS CLI** — required by `start-infra.sh` to pull secrets from AWS Secrets Manager (installed automatically by the script if missing)
- Valid **AWS credentials** with access to the `test/bycrafter/*` secrets in Secrets Manager (region `eu-central-1`)

> The setup scripts (`lib-infra.sh`) will attempt to auto-install missing dependencies (`jq`, `unzip`, `maven`, `node`, `npm`, `aws-cli`) on Linux, macOS and Windows (Git Bash), but it's recommended to have them ready beforehand.

## Directory Structure

The build scripts (`docker-image-build.sh`, `start-infra.sh`) and `docker-compose.yml` reference the application repositories as **sibling directories** (`../<repo>`), one level above `crafter-infra`. Clone all repositories side-by-side under the same parent folder:

```
bycrafter/
├── crafter-infra/           # this repository
├── account-manager/
├── conference-manager/
├── notification-manager/
├── conference-web-api/
└── conference-web-app/
```

```bash
mkdir bycrafter && cd bycrafter

git clone <account-manager-repo-url> account-manager
git clone <conference-manager-repo-url> conference-manager
git clone <notification-manager-repo-url> notification-manager
git clone <conference-web-api-repo-url> conference-web-api
git clone <conference-web-app-repo-url> conference-web-app
git clone <crafter-infra-repo-url> crafter-infra

cd crafter-infra
```

> Each Java repository must be buildable with `mvn -pl <service>-app -am package -DskipTests`, since the Java services use runtime-only Dockerfiles that expect a pre-built jar on the host.

## Configuration (.env)

Before running anything, create your local `.env` file from the provided `.env.example` in the root of `crafter-infra`:

```bash
cp .env.example .env
```

At minimum, fill in your **AWS credentials** and **NODE_AUTH_TOKEN** — they are required for fetching secrets and building the Node.js services:

```dotenv
AWS_ACCESS_KEY_ID=<your-aws-access-key-id>
AWS_SECRET_ACCESS_KEY=<your-aws-secret-access-key>
AWS_REGION=eu-central-1
NODE_AUTH_TOKEN=<your-github-packages-token>
```

Everything else in `.env` is **optional** — `docker-compose.yml` already falls back to sane defaults for local use. Override only when needed, e.g.:

| Variable | Used by | Purpose |
|---|---|---|
| `NODE_AUTH_TOKEN` | `conference-web-api` (build-time) | GitHub Packages token, needed to resolve private `@bycrafter/*-grpc-contract` npm packages |
| `ACCOUNT_MANAGER_GRPC_URL` / `CONFERENCE_MANAGER_GRPC_URL` | `conference-web-api` | Override to `host.docker.internal:<port>` if you stop a core backend container and run it locally from your IDE instead |
| `FRONTEND_URL` | `account-manager`, `conference-web-api` (CORS) | Frontend origin, defaults to `http://localhost:5173` |
| `VITE_API_BASE_URL` | `conference-web-app` (build-time) | Base API path baked into the frontend build, defaults to `/v1` |
| `GRPC_TIMEOUT_MS`, `CIRCUIT_BREAKER_*`, `THROTTLE_*` | `conference-web-api` | gRPC resilience/throttling tuning |

> **Never run `./start-infra.sh` with real DB/Redis/Mongo credentials manually filled in `.env`** — that script calls `fetch_secrets_to_environment` (in `lib-infra.sh`), which pulls all of them from AWS Secrets Manager and exports them into the shell before starting Docker Compose. Only `./docker-image-build.sh` (which does **not** touch Secrets Manager) relies purely on your local `.env` values.

⚠️ **Security note:** never commit a `.env` file containing real secrets (AWS keys, tokens, passwords) to version control. Rotate any credential that may have been accidentally exposed.

## Quick Start

Run these commands from the root of `crafter-infra`, once all sibling repositories are cloned and your `.env` is configured:

```bash
# 1. Configure environment variables
cp .env.example .env        # keep the real .env private; fill in your AWS credentials and NODE_AUTH_TOKEN
```

```bash
# 2. Make the scripts executable
chmod +x docker-image-build.sh start-infra.sh
```

```bash
# 3. Build all application Docker images (jars for Java services + npm builds for Node services)
./docker-image-build.sh
```

```bash
# 4. Fetch secrets from AWS Secrets Manager and start the full stack
./start-infra.sh
```

After `start-infra.sh` completes, the whole YACS platform is up and running:

- Frontend: **http://localhost:8080**
- BFF (API): **http://localhost:3000**
- Zipkin tracing UI: **http://localhost:9411**

> `start-infra.sh` always tears down any previous stack first (`docker compose down -v`, plus force-removal of known containers and the local Mongo data directory), so it's safe to re-run at any time to get a clean restart.

## Services & Ports

| Container | Host Port(s) | Notes |
|---|---|---|
| `conference-web-app` | `8080` → `80` | Frontend, proxies `/v1/*` to the BFF via Nginx |
| `conference-web-api` | `3000` | BFF (NestJS) |
| `account-manager` | `8085`, `6065` (gRPC) | Core backend — accounts/auth |
| `conference-manager` | `8086`, `6075` (gRPC) | Core backend — conferences |
| `notification-manager` | `8095` | Notification service |
| `account-postgres` | `5433` → `5432` | PostgreSQL for `account-manager` |
| `conference-postgres` | `5432` | PostgreSQL for `conference-manager` |
| `redis` | `6379` | Shared cache |
| `kafka` | `9092` → `29092` (host listener) | Event bus, also reachable at `kafka:9092` from other containers |
| `notification-mongodb` | `27017` | MongoDB for `notification-manager` |
| `zipkin` | `9411` | Tracing UI |

Every application service also declares an `extra_hosts: host.docker.internal:host-gateway` entry, so you can stop any one of them and run it locally from your IDE (for debugging) — the remaining containers can still reach it via `host.docker.internal:<port>`, once you override the corresponding `*_URL` variable in `.env`.

## Networks & Volumes

- **Networks:** `postgres`, `spring`, `redis` (all `bridge` drivers) segregate traffic between the data layer, the application layer, and the cache layer.
- **Named volumes:** `account_postgres_data`, `conference_postgres_data`, `kafkadata` persist database/broker state across restarts.
- **Bind mounts:** `./.docker/mongo-data` (Mongo data directory, wiped on every `start-infra.sh` run to guarantee a clean init) and `./.docker/mongo-init/mongo-init.sh` (creates the non-root Mongo app user), plus `./.docker/nginx/default.conf` (Nginx reverse-proxy config for the frontend container).

## Useful Commands

```bash
# View logs for a specific service
docker compose logs -f conference-web-api

# Rebuild a single service's image
docker compose build account-manager

# Stop the full stack (keeps volumes)
docker compose down

# Stop the full stack and remove volumes
docker compose down -v

# Rebuild only the Node-based services (BFF + frontend)
source lib-infra.sh && build_node_application_images
```
