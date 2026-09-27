-- Applied on every startup, so every statement is idempotent.

CREATE TABLE IF NOT EXISTS users (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email         text        NOT NULL UNIQUE,
    password_hash text        NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS posts (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title      text        NOT NULL,
    slug       text        NOT NULL UNIQUE,
    body       text        NOT NULL DEFAULT '',
    published  boolean     NOT NULL DEFAULT false,
    author_id  bigint      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS posts_published_idx ON posts (published, created_at DESC);
