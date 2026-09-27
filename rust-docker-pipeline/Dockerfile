# cargo-chef splits the build in two: your dependencies (slow to compile, rarely
# change) and your code (quick, changes all the time). Docker caches the first.
FROM rust:1.98-slim-trixie AS chef
RUN cargo install cargo-chef --version 0.1.78 --locked
WORKDIR /app

# 1. Plan: boil the project down to recipe.json (manifests + lockfile, no code).
FROM chef AS planner
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo chef prepare --recipe-path recipe.json

# 2. Cook: compile only the dependencies. This layer is reused as long as
#    recipe.json is unchanged, i.e. until Cargo.toml or Cargo.lock change.
FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --locked --recipe-path recipe.json

# 3. Build: compile your code on top of the cached dependencies.
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release --locked

# `docker build --target export --output bin .` writes the binary to ./bin.
FROM scratch AS export
COPY --from=builder /app/target/release/rust-docker-pipeline /

# Run: the binary alone on a minimal, non-root base image.
FROM gcr.io/distroless/cc-debian13:nonroot
COPY --from=builder /app/target/release/rust-docker-pipeline /usr/local/bin/app
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/app"]
