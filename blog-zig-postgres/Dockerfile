FROM debian:trixie-slim AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/*
ARG ZIG_VERSION=0.16.0
RUN curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-$(uname -m)-linux-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /opt \
 && ln -s "/opt/zig-$(uname -m)-linux-${ZIG_VERSION}/zig" /usr/local/bin/zig
WORKDIR /app
# Fetch the dependencies pinned in build.zig.zon in their own cached layer.
COPY build.zig build.zig.zon ./
RUN zig build --fetch
COPY schema.sql ./
COPY src ./src
# -Dcpu=baseline: run on any CPU of this architecture, not just the build machine's.
RUN zig build -Doptimize=ReleaseSafe -Dcpu=baseline

# The binary is fully static: no libc needed at runtime.
FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build /app/zig-out/bin/blog /usr/local/bin/blog
ENV PORT=8080
EXPOSE 8080
CMD ["blog"]
