# Entity-Relationship Diagram — Conference Manager Service

This diagram represents the database schema of the `conference-manager` microservice, derived from its
Spring Data R2DBC entity classes (`@Table`, `@Id`, `@Column`) located in
`conference-manager/conference-manager-data/src/main/java/com/bycrafter/conferencemanager/data/entity`
and the Flyway migration scripts under
`conference-manager/conference-manager-app/src/main/resources/db/migration`.

## Diagram (Crow's Foot Notation)

```mermaid
erDiagram
    PROVIDER ||--o{ PROVIDER_ACCOUNT : "has"
    PROVIDER_ACCOUNT ||--o{ CONFERENCE : "hosts"
    CONFERENCE ||--o{ CONFERENCE_PARTICIPANT : "has attendee"
    CONFERENCE ||--o{ CONFERENCE_STAR : "starred by"
    CONFERENCE ||--o{ SLOT_REQUEST : "receives"

    PROVIDER {
        VARCHAR(36) id PK
        VARCHAR(100) name
        VARCHAR(20) provider_vendor
        VARCHAR(20) provider_type
        VARCHAR(20) status
        BIGINT created_at
        BIGINT updated_at
        BIGINT deleted_at
        VARCHAR(50) created_by
        VARCHAR(50) updated_by
    }

    PROVIDER_ACCOUNT {
        VARCHAR(36) id PK
        VARCHAR(36) provider_id FK
        VARCHAR(100) account_username
        TEXT account_password
        BIGINT created_at
        BIGINT updated_at
        BIGINT deleted_at
        VARCHAR(50) created_by
        VARCHAR(50) updated_by
    }

    CONFERENCE {
        VARCHAR(36) id PK
        VARCHAR(200) title
        TEXT description
        BIGINT start_time
        BIGINT end_time
        VARCHAR(36) provider_account_id FK
        VARCHAR(200) location
        TEXT private_info
        VARCHAR(50) organizer_username
        VARCHAR(50) owner_username
        VARCHAR(150) owner_email
        VARCHAR(20) status
        VARCHAR(500) join_link
        VARCHAR(255) provider_event_id
        BIGINT created_at
        BIGINT updated_at
        BIGINT deleted_at
        VARCHAR(50) created_by
        VARCHAR(50) updated_by
    }

    CONFERENCE_PARTICIPANT {
        VARCHAR(36) id PK
        VARCHAR(36) conference_id FK
        VARCHAR(150) email
        BIGINT created_at
        BIGINT updated_at
        BIGINT deleted_at
        VARCHAR(50) created_by
        VARCHAR(50) updated_by
    }

    CONFERENCE_STAR {
        VARCHAR(36) id PK
        VARCHAR(36) conference_id FK
        VARCHAR(50) username
        BIGINT created_at
        BIGINT updated_at
        BIGINT deleted_at
        VARCHAR(50) created_by
        VARCHAR(50) updated_by
    }

    SLOT_REQUEST {
        VARCHAR(36) id PK
        VARCHAR(36) conference_id FK
        VARCHAR(50) requester_username
        VARCHAR(150) requester_email
        BIGINT requested_start_time
        BIGINT requested_end_time
        TEXT justification
        VARCHAR(20) status
        VARCHAR(64) action_token
        BIGINT token_expires_at
        VARCHAR(255) conference_title
        BIGINT created_at
        BIGINT updated_at
        BIGINT deleted_at
        VARCHAR(50) created_by
        VARCHAR(50) updated_by
    }
```

## Entity Notes

- **PROVIDER**: A conferencing platform provider, e.g. Zoom/Google Meet (`Provider.java`, table `provider`). `provider_vendor` and `provider_type` map to the `ProviderVendor`/`ProviderType` enums.
- **PROVIDER_ACCOUNT**: A credentialed account with a `PROVIDER` (`ProviderAccount.java`, table `provider_account`), `provider_id` is a required foreign key. `account_password` is stored as AES-256-GCM ciphertext (`EncryptionUtil`).
- **CONFERENCE**: The core scheduled meeting entity (`Conference.java`, table `conference`). Requires a `provider_account_id` (the account used to create/host the meeting). `status` maps to `ConferenceStatus` (default `SCHEDULED`).
- **CONFERENCE_PARTICIPANT**: Attendee of a conference identified by e-mail (`ConferenceParticipant.java`, table `conference_participant`); unique per `(conference_id, email)`.
- **CONFERENCE_STAR**: Marks a conference as "starred"/favorited by a given user (`ConferenceStar.java`, table `conference_star`); unique per `(conference_id, username)`.
- **SLOT_REQUEST**: A request to reserve/extend a time slot on a conference (`SlotRequest.java`, table `slot_request`). `status` maps to `SlotRequestStatus` (default `PENDING`); `action_token` is unique when present.

## Relationship Legend

| Notation | Meaning |
|---|---|
| `||--o{` | One-to-Zero-or-Many |
| `||--|{` | One-to-One-or-Many |
| `||--||` | One-to-One |
| `}o--o{` | Many-to-Many |
