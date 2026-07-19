# react-shadcn-starter

Vite + React 19 + TypeScript + Tailwind CSS v3 with [shadcn/ui](https://ui.shadcn.com)
fully configured: CSS-variable theming (zinc, dark by default), the `cn` helper, the
`@/` import alias, and three components included as real source you own —
`Button`, `Card`, `Input`.

## Requirements

- [Bun](https://bun.sh) (or Node 20+ with npm/pnpm — swap the commands accordingly)

## Quickstart

```sh
bun install
bun run dev      # http://localhost:5173
bun run build    # production build in dist/
```

## Adding more components

`components.json` is set up, so the shadcn CLI drops new components straight into
`src/components/ui/`:

```sh
bunx shadcn@latest add dialog
bunx shadcn@latest add dropdown-menu tabs badge
```

Components are plain source files in your tree — edit them freely; there is no
package to stay in sync with.

## Theming

Colors live as HSL CSS variables in `src/index.css` (`:root` for light, `.dark` for
dark) and are mapped to Tailwind utilities in `tailwind.config.js`. Dark mode is
class-based; the starter ships with `class="dark"` on `<html>` — remove it (or
toggle it at runtime) for light mode. To change the palette, regenerate the token
block at ui.shadcn.com/themes and paste it over the one in `src/index.css`.

## Layout

```
components.json        shadcn CLI config (style: new-york, base: zinc)
tailwind.config.js     Tailwind theme mapped to the CSS variables
src/
  index.css            Tailwind directives + shadcn token block
  lib/utils.ts         cn() — clsx + tailwind-merge
  components/ui/       button.tsx, card.tsx, input.tsx
  App.tsx              Demo screen using all three
```

## Docker

Multi-stage build: Bun compiles the app, nginx-alpine serves `dist/` with SPA
fallback (`nginx.conf`).

```sh
docker build -t react-shadcn-starter .
docker run -p 8080:80 react-shadcn-starter
```
