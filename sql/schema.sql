-- =============================================================================
-- (b) SQL Schema (DDL) for snickr
-- CS6083 Project #1 --- Spring 2026
-- Target: PostgreSQL
-- =============================================================================

-- Drop in reverse-dependency order (safe to re-run).
DROP TABLE IF EXISTS messages              CASCADE;
DROP TABLE IF EXISTS channel_invitations   CASCADE;
DROP TABLE IF EXISTS channel_members       CASCADE;
DROP TABLE IF EXISTS channels              CASCADE;
DROP TABLE IF EXISTS workspace_invitations CASCADE;
DROP TABLE IF EXISTS workspace_members     CASCADE;
DROP TABLE IF EXISTS workspaces            CASCADE;
DROP TABLE IF EXISTS users                 CASCADE;

-- -----------------------------------------------------------------------------
CREATE TABLE users (
    user_id       BIGSERIAL    PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,
    username      VARCHAR(64)  NOT NULL UNIQUE,
    nickname      VARCHAR(64)  NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
CREATE TABLE workspaces (
    workspace_id BIGSERIAL    PRIMARY KEY,
    name         VARCHAR(128) NOT NULL,
    description  TEXT,
    created_by   BIGINT       NOT NULL REFERENCES users(user_id),
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (created_by, name)
);

-- -----------------------------------------------------------------------------
CREATE TABLE workspace_members (
    workspace_id BIGINT    NOT NULL REFERENCES workspaces(workspace_id),
    user_id      BIGINT    NOT NULL REFERENCES users(user_id),
    is_admin     BOOLEAN   NOT NULL DEFAULT FALSE,
    joined_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (workspace_id, user_id)
);

-- -----------------------------------------------------------------------------
CREATE TABLE workspace_invitations (
    workspace_id    BIGINT      NOT NULL REFERENCES workspaces(workspace_id),
    invitee_user_id BIGINT      NOT NULL REFERENCES users(user_id),
    invited_by      BIGINT      NOT NULL REFERENCES users(user_id),
    invited_at      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status          VARCHAR(16) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','accepted','declined')),
    PRIMARY KEY (workspace_id, invitee_user_id)
);

-- -----------------------------------------------------------------------------
CREATE TABLE channels (
    channel_id   BIGSERIAL    PRIMARY KEY,
    workspace_id BIGINT       NOT NULL REFERENCES workspaces(workspace_id),
    name         VARCHAR(128) NOT NULL,
    type         VARCHAR(16)  NOT NULL
                 CHECK (type IN ('public','private','direct')),
    created_by   BIGINT       NOT NULL REFERENCES users(user_id),
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (workspace_id, name)
);

-- -----------------------------------------------------------------------------
CREATE TABLE channel_members (
    channel_id BIGINT    NOT NULL REFERENCES channels(channel_id),
    user_id    BIGINT    NOT NULL REFERENCES users(user_id),
    joined_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (channel_id, user_id)
);

-- -----------------------------------------------------------------------------
CREATE TABLE channel_invitations (
    channel_id      BIGINT      NOT NULL REFERENCES channels(channel_id),
    invitee_user_id BIGINT      NOT NULL REFERENCES users(user_id),
    invited_by      BIGINT      NOT NULL REFERENCES users(user_id),
    invited_at      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status          VARCHAR(16) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','accepted','declined')),
    PRIMARY KEY (channel_id, invitee_user_id)
);

-- -----------------------------------------------------------------------------
CREATE TABLE messages (
    message_id     BIGSERIAL PRIMARY KEY,
    channel_id     BIGINT    NOT NULL REFERENCES channels(channel_id),
    sender_user_id BIGINT    NOT NULL REFERENCES users(user_id),
    body           TEXT      NOT NULL,
    posted_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- Secondary indexes to support the query workload in queries.sql
CREATE INDEX idx_messages_channel_time ON messages(channel_id, posted_at);
CREATE INDEX idx_messages_sender       ON messages(sender_user_id);
