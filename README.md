# crafter-infra

Central infrastructure and DevOps repository for **YACS** (Video Conference Management System).

This repository is the **master orchestrator** of the YACS platform. It doesn't contain application code itself — instead, it uses Docker and Docker Compose to containerize and run every microservice and backing service together, in a single, isolated environment:

- **Frontend** — `conference-web-app` (React/Vite SPA, served by Nginx)
- **BFF** — `conference-web-api` (NestJS Backend-for-Frontend)
- **Core Backends** — `account-manager` and `conference-manager` (Spring Boot / R2DBC)
- **Notification Service** — `notification-manager` (Spring Boot / MongoDB)
- **Backing services** — PostgreSQL (x2), Redis, Kafka (KRaft mode), MongoDB

## Table of Contents

- [Default Admin Login](#default-admin-login)
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Configuration (.env)](#configuration-env)
- [Quick Start](#quick-start)
- [Manual Setup (Without Running the Scripts)](#manual-setup-without-running-the-scripts)
- [Services & Ports](#services--ports)
- [Networks & Volumes](#networks--volumes)
- [Useful Commands](#useful-commands)

## Default Admin Login

After the infrastructure is up and running, you can log in to the application using the default admin credentials:

- **Username:** `superadmin`
- **Password:** `admin123`

> ⚠️ It is strongly recommended to change these default credentials after the first login.

## Architecture Overview

`docker-compose.yml` wires together the following containers on three bridge networks (`postgres`, `spring`, `redis`):

| Service | Role | Depends on |
|---|---|---|
| `account-postgres` | PostgreSQL DB for `account-manager` | — |
| `conference-postgres` | PostgreSQL DB for `conference-manager` | — |
| `redis` | Shared cache, used by `account-manager`, `conference-manager`, `conference-web-api` | — |
| `kafka` | Event bus (KRaft, single broker) used by all three Java services | — |
| `notification-mongodb` | MongoDB store for `notification-manager` | — |
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
- **Java 25+ & Maven** — required to build the three Java services' jars before their Docker images can be built
- **Node.js & npm** — required to build `conference-web-api` / `conference-web-app` images
- **AWS CLI** — required by `start-infra.sh` to pull secrets from AWS Secrets Manager
- **jq** — used to parse the JSON secrets returned by AWS Secrets Manager
- **unzip** — required to install AWS CLI on Linux
- Valid **AWS credentials** with access to the `test/bycrafter/*` secrets in Secrets Manager (region `eu-central-1`)
- **Windows only:** **WSL2** (Windows Subsystem for Linux, version 2) — required by Docker Desktop as its backend, plus a Linux distribution (e.g. Ubuntu) installed under WSL2 to get a proper Bash shell for running the `.sh` scripts (see [Windows-specific setup](#windows-specific-setup-wsl2) below)

> The scripts (`lib-infra.sh`) **no longer install any dependency automatically**. `docker-image-build.sh` / `start-infra.sh` only *check* that `git`, `docker`, `docker compose`, `jq`, `unzip` and the `aws` CLI are already present on your `PATH` and will exit with an error message if any of them is missing — you must install every tool yourself beforehand (see below).

### Installing prerequisites manually

Since the scripts only check for (and never install) dependencies, you must install each tool yourself using the commands below before running `docker-image-build.sh` / `start-infra.sh`.

**Linux (Debian/Ubuntu — `apt-get`):**

```bash
sudo apt-get update
sudo apt-get install -y git unzip jq maven docker.io docker-compose-plugin nodejs npm
```

**Linux (Fedora — `dnf`):**

```bash
sudo dnf install -y git unzip jq maven docker docker-compose-plugin nodejs npm
```

**Linux (CentOS/RHEL — `yum`):**

```bash
sudo yum install -y git unzip jq maven docker docker-compose-plugin nodejs npm
```

**Linux (Arch — `pacman`):**

```bash
sudo pacman -Sy --noconfirm git unzip jq maven docker docker-compose nodejs npm
```

> On Linux, after installing Docker via a package manager, enable the service and add your user to the `docker` group so you don't need `sudo` for every command:
>
> ```bash
> sudo systemctl enable --now docker
> sudo usermod -aG docker "$USER"
> # log out and back in (or run `newgrp docker`) for the group change to take effect
> ```

**AWS CLI on Linux** (not available via most package managers, install from the official installer):

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf awscliv2.zip aws/
```

Right after installing the AWS CLI, configure your AWS credentials (needed to fetch secrets) — do this at the start, before installing the remaining tools:

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, default region (eu-central-1) and output format (json)
```

**macOS (Homebrew):**

```bash
brew install git unzip jq maven awscli node
brew install --cask docker
# Then start Docker Desktop once from Applications so its background daemon is running
```

**Windows (winget, in PowerShell or Git Bash):**

```powershell
winget install -e --id Git.Git
winget install -e --id jqlang.jq
winget install -e --id GNU.Unzip
winget install -e --id Apache.Maven
winget install -e --id OpenJS.NodeJS
winget install -e --id Amazon.AWSCLI
winget install -e --id Docker.DockerDesktop
# Then start Docker Desktop once (and possibly reboot) so its background daemon is running
```

#### Windows-specific setup (WSL2)

Docker Desktop on Windows **requires WSL2** (Windows Subsystem for Linux, version 2) as its backend — plain Hyper-V-only setups or older WSL1 installs are not sufficient. Also, since `docker-image-build.sh` / `start-infra.sh` are Bash scripts, you need a real Bash shell to run them (Git Bash works for most commands, but running the scripts *inside* a WSL2 Linux distribution is the most reliable option).

1. **Enable WSL2 and install a Linux distribution** (run in an elevated/Administrator PowerShell):

   ```powershell
   wsl --install
   # Installs WSL2 + the default Ubuntu distribution. Reboot when prompted.
   ```

   If WSL was already installed previously (e.g. only WSL1), make sure it's upgraded to version 2:

   ```powershell
   wsl --set-default-version 2
   wsl --update
   wsl --list --verbose   # confirm your distro shows "VERSION 2"
   ```

2. **Verify virtualization is enabled** in your BIOS/UEFI (Intel VT-x / AMD-V) — WSL2 and Docker Desktop won't start without it.

3. **Install/reconfigure Docker Desktop to use the WSL2 backend**: open Docker Desktop → *Settings* → *General* → enable **"Use the WSL 2 based engine"**, then under *Resources* → *WSL Integration*, enable integration with your installed distro (e.g. Ubuntu).

4. **Install the remaining tools inside your WSL2 distro** (it behaves like a real Linux box), using the **Linux (Debian/Ubuntu — `apt-get`)** commands from the section above — this gives you a native Bash environment where `git`, `jq`, `unzip`, `maven`, `node`/`npm`, `aws` CLI and the Docker CLI (talking to the Docker Desktop daemon) all work exactly like on Linux.

5. Run `docker-image-build.sh` / `start-infra.sh` **from inside the WSL2 terminal** (not plain `cmd.exe`/PowerShell) for the smoothest experience.

After installing, verify each tool is on your `PATH`:

```bash
git --version
docker --version
docker compose version   # or: docker-compose --version
mvn --version
node --version
npm --version
aws --version
jq --version
unzip -v
```

> AWS credentials should already be configured at this point (see the AWS CLI installation step above) — this is only a reminder to double check before continuing.

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

Alternatively, once `crafter-infra` itself is cloned, you can run the standalone `clone-repos.sh` script to automatically clone the remaining 5 sibling repositories (`account-manager`, `conference-manager`, `notification-manager`, `conference-web-api`, `conference-web-app`) into the parent directory — it skips any repository that's already cloned, so it's safe to re-run:

```bash
chmod +x clone-repos.sh
./clone-repos.sh
```

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

> `start-infra.sh` always tears down any previous stack first (`docker compose down -v`, plus force-removal of known containers and the local Mongo data directory), so it's safe to re-run at any time to get a clean restart.

## Manual Setup (Without Running the Scripts)

The application Docker images are **already built and pushed** to the registry, so in the normal case you don't need to build anything yourself — you only need to execute `start-infra.sh` to pull the images and bring up the full stack:

```bash
chmod +x start-infra.sh
./start-infra.sh
```

`start-infra.sh` only checks that `git`, `docker` and `docker compose` are already present on your `PATH` (no AWS CLI installation/configuration is required for this step); see [Installing prerequisites manually](#installing-prerequisites-manually) above if any of them is missing.

If you need to (re)build the images yourself (e.g. after changing application code), you can run `docker-image-build.sh` to build them locally:

```bash
chmod +x docker-image-build.sh
./docker-image-build.sh
```

And if you need to publish newly built images to the registry, run `docker-image-registiry.sh` (docker registry push):

```bash
chmod +x docker-image-registiry.sh
./docker-image-registiry.sh
```

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
