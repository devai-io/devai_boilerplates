FROM rust:1.98-slim-trixie AS build
WORKDIR /app
# Build the dependencies against a dummy main first, so this layer stays
# cached until Cargo.toml or Cargo.lock change.
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs \
 && cargo build --release --locked \
 && rm -rf src
COPY schema.sql ./
COPY src ./src
RUN touch src/main.rs && cargo build --release --locked

FROM gcr.io/distroless/cc-debian13:nonroot
COPY --from=build /app/target/release/blog-rust-postgres /usr/local/bin/blog
ENV PORT=8080
EXPOSE 8080
CMD ["blog"]
