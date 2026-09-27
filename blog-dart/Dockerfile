FROM dart:3.13 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get --enforce-lockfile
COPY . .
RUN dart compile js -O2 -o build/main.dart.js web/main.dart

FROM nginxinc/nginx-unprivileged:1.30-alpine
# The image's entrypoint runs envsubst on templates/*.template, so API_URL is read at start-up.
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY web/index.html web/styles.css /usr/share/nginx/html/
COPY --from=build /app/build/main.dart.js /usr/share/nginx/html/
ENV API_URL=http://host.docker.internal:8080
EXPOSE 8080
