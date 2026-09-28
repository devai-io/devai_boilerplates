# rust-docker-pipeline

Build and ship Rust in Docker without waiting on your dependencies every time:
cargo-chef compiles them into their own cached layer, so a code change rebuilds in
seconds. And when your server is too small to compile Rust, ship a prebuilt binary.

## Run

    git clone https://github.com/devai-io/devai_boilerplates.git
    cd devai_boilerplates/rust-docker-pipeline
    docker compose up --build

http://localhost:8080 answers `Hello from rust-docker-pipeline!` (`/health` → `ok`).
The first build compiles cargo-chef and every dependency. Now change `GREETING` in
`src/main.rs` and run the same command again: only your crate recompiles.

Without Docker: `cargo run` (Rust 1.98, the toolchain the Dockerfile pins).

## How it works

The `Dockerfile` builds in three steps:

1. **planner** — `cargo chef prepare` boils the project down to `recipe.json`: the
   manifests and the lockfile, none of your code.
2. **builder** — `cargo chef cook` compiles only the dependencies in that recipe.
   Docker caches this layer until `Cargo.toml` or `Cargo.lock` change.
3. `cargo build --release --locked` then compiles your code on top of it.

The runtime stage is `gcr.io/distroless/cc-debian13:nonroot`: the binary, glibc and
CA certificates, no shell, not root. See the cache at work with
`docker build --progress=plain .` after a code-only change — the `cargo chef cook`
step reports `CACHED`.

**Shipping a prebuilt binary.** Compiling Rust takes CPU and RAM a small server may
not have. Build on your machine (or in CI) and export the binary:

    docker build --target export --output bin .    # writes bin/rust-docker-pipeline

Copy `bin/`, `Dockerfile.prebuilt` and `compose.prebuilt.yaml` to the server and run:

    docker compose -f compose.prebuilt.yaml up -d --build

`Dockerfile.prebuilt` only copies the binary into the same distroless image — no
toolchain, no compile. The binary is linked against Debian trixie's glibc, which is
what `cc-debian13` ships. Build for the server's CPU (add `--platform linux/amd64` on
an ARM laptop), and move `bin/` with scp or rsync: it is git-ignored.

## Layout

    Dockerfile              chef → planner → builder → runtime, plus the export stage
    Dockerfile.prebuilt     runtime image around an existing bin/rust-docker-pipeline
    compose.prebuilt.yaml   runs Dockerfile.prebuilt
    src/main.rs             a tiny axum app: / and /health

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/rust-docker-pipeline my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — Deploy & Infra: build and ship pipelines.
