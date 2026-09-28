# react-tailwind-starter

The quickest sane React start: Vite 8, React 19, TypeScript and Tailwind CSS v4.
No router, no state library, no component framework — a clean slate that builds
in seconds and hot-reloads instantly.

## Run

Get it: `git clone https://github.com/devai-io/devai_boilerplates.git`, then `cd devai_boilerplates/react-tailwind-starter`

    docker compose up --build

Open http://localhost:8080 — the production build, served by nginx.

Hot-reload dev server (Node 24):

    npm ci
    npm run dev        # http://localhost:5173

## How it works

Tailwind v4 is configured in CSS, not JavaScript. `src/index.css` is a single
`@import "tailwindcss";`, and the `@tailwindcss/vite` plugin finds the class names
in your source files. There is no `tailwind.config.js` and no PostCSS config — add
design tokens with an `@theme { … }` block in the same CSS file.

`npm run build` type-checks (`tsc --noEmit`) and then bundles into `dist/`.

## Layout

    vite.config.ts   React + Tailwind Vite plugins
    src/index.css    Tailwind entry point (add @theme tokens here)
    src/App.tsx      landing screen — replace and go
    nginx.conf       SPA fallback + long-lived caching for hashed /assets/
    Dockerfile       npm ci + vite build, served by unprivileged nginx

## Deploy

Make this folder the root of your own repo (`cp -r devai_boilerplates/react-tailwind-starter my-app`,
then `git init` inside it), push it to GitHub, and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — UI starters: `react-tailwind-starter` and
[`react-shadcn-starter`](https://github.com/devai-io/devai_boilerplates/tree/main/react-shadcn-starter).
