# Build
FROM rust:1-slim-trixie AS builder
WORKDIR /app
COPY Cargo.toml schema.sql ./
COPY src ./src
RUN cargo build --release

# Run
FROM debian:trixie-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/blog-rust-postgres /usr/local/bin/blog
ENV PORT=8080
EXPOSE 8080
CMD ["blog"]
