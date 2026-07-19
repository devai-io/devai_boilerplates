# react-tailwind-starter

The quickest possible React start: Vite, React 19, TypeScript and Tailwind CSS v3.
No router, no state library, no component framework — a clean slate that builds in
seconds and hot-reloads instantly.

## Requirements

- [Bun](https://bun.sh) (or Node 20+ with npm/pnpm — swap the commands accordingly)

## Quickstart

```sh
bun install
bun run dev      # http://localhost:5173
bun run build    # production build in dist/
```

## Layout

```
index.html          Vite entry
vite.config.ts      Vite + React plugin
tailwind.config.js  Tailwind content globs (extend the theme here)
postcss.config.js   Tailwind + autoprefixer
src/
  main.tsx          React root
  App.tsx           Landing screen — replace and go
  index.css         Tailwind directives
```

## Docker

Multi-stage build: Bun compiles the app, nginx-alpine serves `dist/` with SPA
fallback (`nginx.conf`).

```sh
docker build -t react-tailwind-starter .
docker run -p 8080:80 react-tailwind-starter
```
