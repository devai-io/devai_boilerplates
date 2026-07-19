# Build
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
# API base is compiled in at build time: docker build --build-arg NG_APP_API_URL=...
ARG NG_APP_API_URL=http://localhost:8080
RUN npx ng build --define "NG_APP_API_URL='${NG_APP_API_URL}'"

# Serve
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/blog-angular/browser /usr/share/nginx/html
EXPOSE 80
