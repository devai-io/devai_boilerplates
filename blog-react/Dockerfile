FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.30-alpine
# The image's entrypoint runs envsubst on templates/*.template, so API_URL is read at start-up.
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
ENV API_URL=http://host.docker.internal:8080
EXPOSE 8080
