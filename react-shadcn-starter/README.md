# react-shadcn-starter

Vite 8 + React 19 + TypeScript + Tailwind CSS v4 with [shadcn/ui](https://ui.shadcn.com)
set up the way the shadcn CLI does it today: the `radix-nova` style, OKLCH CSS-variable
theming (dark by default), the `@/` import alias, and three components you own as
source — `Button`, `Card`, `Input`.

## Run

Get it: `git clone https://git.devai.io/templates/react-shadcn-starter.git`

    docker compose up --build

Open http://localhost:8080 — the production build, served by nginx.

Hot-reload dev server (Node 24):

    npm ci
    npm run dev        # http://localhost:5173

## How it works

shadcn/ui is not a component package: `components.json` tells the CLI where
components live, and each `add` copies real source into `src/components/ui/`.

    npx shadcn@latest add dialog
    npx shadcn@latest add dropdown-menu tabs badge

Edit the files freely — there is nothing to stay in sync with. Components are
built on the `radix-ui` primitives and merge class names with `cn`.

Theming is CSS-first (Tailwind v4 — no `tailwind.config.js`): colors are OKLCH
variables in `src/index.css` (`:root` for light, `.dark` for dark), mapped to
utilities by the `@theme inline` block. Dark mode is class-based and `index.html`
ships `class="dark"` on `<html>` — remove it (or toggle it at runtime) for light
mode. To change the palette, generate a theme at ui.shadcn.com and paste its
variables over the ones in `src/index.css`.

## Layout

    components.json        shadcn CLI config (style radix-nova, base color neutral)
    vite.config.ts         React + Tailwind plugins; @/ alias read from tsconfig.json
    src/index.css          Tailwind, shadcn base styles, theme variables
    src/lib/utils.ts       cn() — class-name merging
    src/components/ui/     button.tsx, card.tsx, input.tsx
    src/App.tsx            demo screen using all three
    nginx.conf             SPA fallback + long-lived caching for hashed /assets/

## Deploy

Push to your own GitHub repo and the shipped workflow
(`.github/workflows/ci.yml`) tests the compose stack, publishes the image to
GHCR, and — once you set the `DEPLOY_HOST` / `DEPLOY_USER` variables and
`DEPLOY_KEY` secret — deploys it to your server over ssh.

---
Part of [devai.io](https://devai.io) — UI starters:
[`react-tailwind-starter`](https://git.devai.io/templates/react-tailwind-starter) and
`react-shadcn-starter`.
