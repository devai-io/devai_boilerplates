create table if not exists users (
    id            bigint generated always as identity primary key,
    email         text not null unique,
    password_hash text not null,
    created_at    timestamptz not null default now()
);

create table if not exists posts (
    id         bigint generated always as identity primary key,
    title      text not null,
    slug       text not null unique,
    body       text not null,
    published  boolean not null default false,
    author_id  bigint not null references users (id) on delete cascade,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- When the post was first published, null while a draft. add column if not
-- exists also upgrades databases created before the column existed.
alter table posts add column if not exists published_at timestamptz;

create index if not exists posts_published_at_recent on posts (published_at desc) where published;
