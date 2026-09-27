FROM debian:trixie-slim AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl xz-utils libmongoc-dev pkg-config \
 && rm -rf /var/lib/apt/lists/*
ARG ZIG_VERSION=0.16.0
RUN curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-$(uname -m)-linux-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /opt \
 && ln -s "/opt/zig-$(uname -m)-linux-${ZIG_VERSION}/zig" /usr/local/bin/zig
WORKDIR /app
COPY build.zig build.zig.zon ./
COPY src ./src
# -Dcpu=baseline: run on any CPU of this architecture, not just the build machine's.
RUN zig build -Doptimize=ReleaseSafe -Dcpu=baseline

FROM debian:trixie-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libmongoc-1.0-0t64 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/zig-out/bin/blog /usr/local/bin/blog
USER nobody
ENV PORT=8080
EXPOSE 8080
CMD ["blog"]
