# --- build stage -------------------------------------------------------------
FROM debian:bookworm-slim AS build

ARG ZIG_VERSION=0.16.0
# Set to aarch64 when building on ARM hosts.
ARG ZIG_ARCH=x86_64

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl xz-utils ca-certificates libmongoc-dev pkg-config \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-${ZIG_ARCH}-linux-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /opt \
 && ln -s "/opt/zig-${ZIG_ARCH}-linux-${ZIG_VERSION}/zig" /usr/local/bin/zig

WORKDIR /app
COPY build.zig build.zig.zon ./
COPY src ./src
RUN zig build -Doptimize=ReleaseSafe

# --- runtime stage -----------------------------------------------------------
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends libmongoc-1.0-0 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/zig-out/bin/blog /usr/local/bin/blog

ENV PORT=8080
EXPOSE 8080
USER nobody
CMD ["blog"]
