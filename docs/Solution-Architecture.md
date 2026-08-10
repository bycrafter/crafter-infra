# YACS Project - Solution Architecture and Technology Selection Criteria

> This document was produced by analyzing the actual configuration of this repository (`docker-compose.yml`, `.env`, `README.md`, `docs/HLD.md`) together with the sibling application repositories it orchestrates (`account-manager`, `conference-manager`, `notification-manager`, `conference-web-api`, `conference-web-app`). `crafter-infra` itself does not contain application source code — it is the infrastructure/orchestration repository for the YACS (Video Conference Management System) platform — so it is used here as the ground truth for network topology, service boundaries, and runtime configuration.

## 1. Software Architecture Approach

YACS is built on a **Microservices Architecture** combined with an **Event-Driven Architecture (EDA)** and a **Backend for Frontend (BFF)** pattern:

- **Microservices**: Each business capability is isolated into its own deployable unit with its own database and technology stack: `account-manager` (identity/auth), `conference-manager` (conference/meeting domain), and `notification-manager` (notifications/audit). This isolation was chosen so that each domain can be scaled, deployed, and evolved independently — a failure or slow deployment in `notification-manager`, for example, does not affect the ability of users to authenticate or schedule a conference.
- **Backend for Frontend (BFF)**: `conference-web-api` (NestJS) sits between the SPA and the core domain services. It exposes a REST API tailored to the frontend's needs, translates those calls into internal **gRPC** calls to `account-manager` and `conference-manager`, and centralizes cross-cutting concerns (CORS, throttling, circuit breaking) so that the frontend does not need to know about the internal service topology or protocol.
- **Event-Driven Communication**: `account-manager` and `conference-manager` publish domain events to **Apache Kafka** (KRaft mode, single broker in this environment), which `notification-manager` consumes to trigger emails/notifications. This decouples the "conference created" business action from the "send a notification email" side effect, so the core services do not block on, or fail because of, the availability of the notification/SMTP pipeline.
- **Fault Tolerance & Scalability**: The BFF layer implements **circuit breaking** (`CIRCUIT_BREAKER_FAILURE_THRESHOLD`, `CIRCUIT_BREAKER_RESET_TIMEOUT_MS`) and **throttling** (`THROTTLE_TTL_MS`, `THROTTLE_LIMIT`) around its gRPC calls to the core backends, preventing cascading failures if a downstream service becomes slow or unavailable. Each service is independently containerized and stateless (session/cache state is externalized to Redis), which allows any of them to be horizontally scaled without code changes.
- **Centralized Secrets Management**: All Java services import their runtime configuration from **AWS Secrets Manager** (`spring.config.import: aws-secretsmanager:...`) instead of hardcoding credentials, which keeps sensitive configuration out of source control and images, and allows credential rotation without redeployment.

## 2. Technologies Used and Selection Criteria

### 2.1. Frontend (Client)

**Technology:** React + Vite, served as a static Single Page Application (SPA) via Nginx (`conference-web-app`).

- **Vite** was chosen over more traditional bundlers for its fast dev-server startup and HMR (Hot Module Reload), improving developer productivity.
- **React**'s component model and unidirectional data flow are well suited to a highly interactive scheduling/conferencing UI where multiple views (calendar, meeting room, account settings) need to share and react to state changes.
- Serving the built assets through **Nginx** keeps the frontend container lightweight and stateless; a dedicated reverse-proxy rule (`.docker/nginx/default.conf`) forwards `/v1/*` calls to the BFF, so the SPA and its API share the same origin in production, avoiding CORS complexity for end users while `CORS_ORIGIN` is still explicitly configured on the BFF for local/dev cross-origin scenarios.

### 2.2. Backend (Server)

**Technology:** Spring Boot (reactive stack, R2DBC, gRPC) for `account-manager`/`conference-manager`, Spring Boot + MongoDB for `notification-manager`, and NestJS (Node.js) for the BFF (`conference-web-api`).

- **Spring Boot with a reactive stack (R2DBC)** was selected for the core domain services because conference/account management is I/O bound (database, Kafka, gRPC) and needs to scale to many concurrent connections without a thread-per-request cost; the non-blocking model gives better resource utilization under load than a traditional blocking JPA stack.
- **gRPC** (via generated `@bycrafter/*-grpc-contract` contracts) is used for internal service-to-service communication because it is a strongly-typed, contract-first, low-latency binary protocol — a better fit for internal orchestration traffic than JSON/REST, while still allowing the BFF to expose a friendlier REST interface to the browser.
- **NestJS** was chosen for the BFF layer because of its first-class TypeScript support, modular architecture (guards, interceptors, pipes), and its ecosystem for implementing cross-cutting resilience concerns (circuit breakers, throttling, gRPC clients) in a maintainable way, while keeping the BFF technologically decoupled from the Java core services (fitting the "polyglot microservices" approach).

### 2.3. Database and Persistence

**Technology:** Polyglot persistence — PostgreSQL (x2), MongoDB, and Redis.

- **PostgreSQL** (`account-postgres`, `conference-postgres`) is used for the account and conference domains because this data is inherently relational and transactional (users, roles, scheduled conferences, participants) and benefits from **ACID guarantees**, referential integrity, and schema migrations (Flyway, via `FLYWAY_URL`). Each core service owns a dedicated PostgreSQL instance/database, respecting the "database per service" microservices principle and avoiding coupling between the account and conference domains at the data layer.
- **MongoDB** (`notification-mongodb`) backs `notification-manager` because notification/audit records (delivery history, templates, event payloads) are naturally document-shaped, schema-flexible, and write-heavy/append-only — a workload where a relational schema would add unnecessary rigidity, while MongoDB's document model maps closely to the JSON-like event payloads consumed from Kafka.
- **Redis** is used as a shared caching and session layer across `account-manager`, `conference-manager`, and `conference-web-api`. Its in-memory, low-latency access pattern is ideal for frequently-read data (session tokens, rate-limit counters, cached lookups), reducing load on the primary databases and improving response times for the BFF.

### 2.4. Messaging (Message Broker)

**Technology:** Apache Kafka (KRaft mode, single broker in this environment).

- Kafka was selected to enable **asynchronous, non-blocking communication** between services, most notably from `account-manager`/`conference-manager` (event producers) to `notification-manager` (event consumer). When a conference is created or a user is registered, the producing service publishes an event and returns immediately, without waiting for the notification to be sent — the actual email/notification delivery happens out-of-band.
- This choice provides **temporal decoupling** (the notification service can be down or slow without blocking core business operations), **durability** (events persist on the log and can be replayed/retried), and a natural extension point — additional consumers (e.g., analytics, audit) can subscribe to the same topics without any change to the producers.
- Running Kafka in **KRaft mode** (no separate ZooKeeper) simplifies the operational footprint for this environment while preserving the same producer/consumer API used in production-grade multi-broker deployments.

## 3. Security and Authentication

- **JWT-based Authentication**: End-user authentication is handled by `account-manager`, the dedicated identity/account microservice, which issues and validates credentials for the platform. The BFF (`conference-web-api`) sits in front of the browser and is the natural enforcement point for propagating and validating the resulting JWT/session on every request before it is translated into an internal gRPC call — centralizing auth checks at the gateway keeps the core services focused on business logic and avoids duplicating auth logic across every backend.
- **Role-Based Access Control (RBAC)**: The platform's roles (e.g., `STANDARD_USER`, `ORGANIZER`, `ADMIN`) are modeled and enforced starting at the account domain (`account-manager`) and are checked at the BFF/Gateway layer for each incoming request, ensuring that only authorized roles can perform sensitive actions (e.g., only an `ORGANIZER`/`ADMIN` can create or manage a conference on behalf of others).
- **Session/Token Caching**: Redis is shared between `account-manager`, `conference-manager`, and `conference-web-api` specifically to support fast session/token validation and cache lookups at the gateway without a round-trip to the identity service on every request.
- **Secrets Isolation**: Sensitive configuration (DB credentials, Redis credentials, `master_encryption_key` for `conference-manager`, SMTP credentials for `notification-manager`) is never stored in the repository; it is fetched at startup from **AWS Secrets Manager**, and build-time-only secrets (e.g., `NODE_AUTH_TOKEN` for private npm packages) are kept separate from runtime secrets. `conference-manager` additionally performs **application-level encryption** (`master_encryption_key`) for particularly sensitive fields (e.g., stored external-provider credentials/tokens), adding a defense-in-depth layer beyond transport/database security.

## 4. External System Integrations and Design Patterns

- **Google Calendar / Meet (and other provider) Integration**: `conference-manager` is the domain owner for scheduling and needs to synchronize meetings with external calendar/conferencing providers (e.g., Google Calendar/Meet). This class of integration typically relies on an **OAuth2 Refresh Token flow**: the user grants offline access once, the service persists a long-lived refresh token (protected via the application-level encryption described in Section 3), and uses it to silently obtain short-lived access tokens for subsequent API calls (creating events, generating meeting links) without requiring the user to re-authenticate.
- **Strategy Pattern for Conference Providers**: Because YACS needs to support multiple virtual meeting providers (e.g., Google Meet, Zoom, Microsoft Teams) with different SDKs/APIs but a common set of operations (create meeting, generate join link, cancel meeting), `conference-manager` is designed around a **Strategy Pattern**, exposed through a `VirtualProviderGateway` abstraction. Each concrete provider (Google, Zoom, Teams) implements the same interface, and the appropriate strategy is selected at runtime based on the organizer's configured/preferred provider. This keeps the core conference-scheduling logic provider-agnostic and makes adding a new provider a matter of implementing one new strategy class, without touching the rest of the domain logic.
- **Asynchronous Notification of External Events**: Once a conference (and its external provider meeting) is created, `conference-manager` publishes a Kafka event that `notification-manager` consumes to email the invited participants — keeping the external-provider integration and the notification/delivery concern fully decoupled from one another.
